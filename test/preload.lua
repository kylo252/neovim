-- Modules loaded here will not be cleared and reloaded by Busted.
-- See #2082, Olivine-Labs/busted#62 and Olivine-Labs/busted#643

local test_type

for _, value in pairs(_G.arg) do
  if value:match('IS_FUNCTIONAL_TEST') then
    test_type = 'functional'
  elseif value:match('IS_UNIT_TEST') then
    test_type = 'unit'
  elseif value:match('IS_BENCHMARK_TEST') then
    test_type = 'benchmark'
  end
end

local luv = require('luv')

local function join_paths(...)
  local path_sep = luv.os_uname().version:match('Windows') and '\\' or '/'
  local result = table.concat({ ... }, path_sep)
  return result
end

local function is_file(path)
  local stat = luv.fs_stat(path)
  return stat and stat.type == 'file' or false
end

local function is_directory(path)
  local stat = luv.fs_stat(path)
  return stat and stat.type == 'directory' or false
end

local function rmrf(path)
  if is_directory(path) then
    return luv.fs_rmdir(path)
  elseif is_file(path) then
    return luv.fs_unlink(path)
  else
    return
  end
end

--[[
  TODO(kylo252): we should probably override TMPDIR dynamically per test regardless,
  but that seems to cause issues for rpc tests where TMPDIR isn't passed along
  -- luv.os_setenv('TMPDIR', NVIM_TEST_TMPDIR)
--]]

local NEOVIM_BUILD_DIR = os.getenv('NEOVIM_BUILD_DIR') or join_paths(luv.cwd(), 'build')

local base_dirs = {
  XDG_CONFIG_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'config'),
  XDG_DATA_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'data'),
  XDG_STATE_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'state'),
  XDG_CACHE_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'cache'),
}

-- NOTE: os_setenv() isn't thread-safe according to luv's docs
for k, v in pairs(base_dirs) do
  luv.os_setenv(k, v)
end

local NVIM_TEST_TMPDIR = os.getenv('TMPDIR')
if not NVIM_TEST_TMPDIR then
  -- NVIM_TEST_TMPDIR = luv.fs_mkdtemp(join_paths(luv.os_tmpdir(), 'Xtest_nvim.XXXXXXXXXX'))
  NVIM_TEST_TMPDIR = join_paths(NEOVIM_BUILD_DIR, 'Xtest_tmpdir')
  luv.os_setenv('TMPDIR', NVIM_TEST_TMPDIR)
end

local NVIM_LOG_FILE = os.getenv('NVIM_LOG_FILE')
if not NVIM_LOG_FILE then
  NVIM_LOG_FILE = join_paths(NVIM_TEST_TMPDIR, '.nvimlog')
  luv.os_setenv('NVIM_LOG_FILE', NVIM_LOG_FILE)
end

luv.os_unsetenv('XDG_DATA_DIRS')
luv.os_unsetenv('NVIM')

local global_helpers = require('test.helpers')

global_helpers.is_file = is_file
global_helpers.is_directory = is_directory
global_helpers.join_paths = join_paths
global_helpers.rmrf = rmrf

local lfs = require('lfs')

local ffi_ok, ffi = pcall(require, 'ffi')

local iswin = global_helpers.iswin
if iswin() and ffi_ok then
  ffi.cdef([[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]])
  ffi.C._set_fmode(0x8000)
end

if test_type == 'unit' then
  require('test.unit.preprocess')
end

require('test.' .. test_type .. '.helpers')(nil)
package.loaded['test.' .. test_type .. '.helpers'] = nil

local testid = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

local cleanupTempFolders = function()
  for _, path in pairs(base_dirs) do
    if path:match('Xtest_xdg') then
      rmrf(path)
    end
  end
  for f in lfs.dir(NEOVIM_BUILD_DIR) do
    if f:match('Xtest') then
      rmrf(f)
    end
  end
end

local testEnd = function(_, _, status, _)
  if status == 'error' then
    return
  end
  cleanupTempFolders()
  return nil, true
end

-- Global before_each. https://github.com/Olivine-Labs/busted/issues/613
local before_each = function()
  local id = ('T%d'):format(testid())
  _G._nvim_test_id = id

  NVIM_LOG_FILE = join_paths(NVIM_TEST_TMPDIR, '.nvimlog.' .. id)
  luv.os_setenv('NVIM_LOG_FILE', NVIM_LOG_FILE)
  for _, path in pairs(base_dirs) do
    if not is_directory(join_paths(path, 'nvim')) then
      -- NOTE: fs_mkdir doesn't seem to handle `mkdir -p` correctly
      local dir = require('pl.dir')
      dir.makepath(join_paths(path, 'nvim'), tonumber('0700'))
    end
  end
  return nil, true
end

local busted = require('busted')
busted.subscribe({ 'test', 'start' }, before_each, {
  -- Ensure our --helper is handled before --output (see busted/runner.lua).
  priority = 1,
  -- Don't generate a test-id for skipped tests. /shrug
  predicate = function(element, _, status)
    return not (element.descriptor == 'pending' or status == 'pending')
  end,
})

busted.subscribe({ 'test', 'end' }, testEnd, {
  -- Ensure our --helper is handled after --output (see busted/runner.lua).
  priority = 101,
})
