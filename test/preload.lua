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
-- NOTE: os_setenv() isn't thread-safe according to luv's docs

local function is_file(filename)
  local stat = luv.fs_stat(filename)
  return stat and stat.type == 'file' or false
end

local function is_directory(filename)
  local stat = luv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

local function join_paths(...)
  local path_sep = luv.os_uname().version:match('Windows') and '\\' or '/'
  local result = table.concat({ ... }, path_sep)
  return result
end

local NVIM_TEST_TMPDIR = os.getenv('NVIM_TEST_TMPDIR')
if not NVIM_TEST_TMPDIR or not is_directory(NVIM_TEST_TMPDIR) then
  NVIM_TEST_TMPDIR = luv.fs_mkdtemp(join_paths(luv.os_tmpdir(), 'Xtest_nvim.XXXXXXXXXX'))
end
luv.os_setenv('NVIM_TEST_TMPDIR', NVIM_TEST_TMPDIR)

--[[
  TODO(kylo252): we should probably override TMPDIR dynamically per test regardless,
  but that seems to cause issues for rpc tests where TMPDIR isn't passed along
  -- luv.os_setenv('TMPDIR', NVIM_TEST_TMPDIR)
--]]

local NVIM_LOG_FILE = os.getenv('NVIM_LOG_FILE')
if not NVIM_LOG_FILE or not is_file(NVIM_LOG_FILE) then
  local _, tmpfile = luv.fs_mkstemp(join_paths(NVIM_TEST_TMPDIR, 'nvim_log.XXXXXXXXXX'))
  luv.os_setenv('NVIM_LOG_FILE', tmpfile)
end

luv.os_unsetenv('XDG_DATA_DIRS')
luv.os_unsetenv('NVIM')

local fs = require('vim.fs')
fs.join_paths = join_paths
fs.is_file = is_file
fs.is_directory = is_directory

local global_helpers = require('test.helpers')

local ffi_ok, ffi = pcall(require, 'ffi')
local lfs = require('lfs')

local iswin = global_helpers.iswin
if iswin() and ffi_ok then
  ffi.cdef([[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]])
  ffi.C._set_fmode(0x8000)
end

if test_type == 'unit' then
  local preprocess = require('test.unit.preprocess')
end

local helpers = require('test.' .. test_type .. '.helpers')(nil)
