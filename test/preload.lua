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
local fs = require'vim.fs'

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

local NVIM_TMPDIR = join_paths(luv.os_tmpdir(), 'Xtest_nvim')
if not is_directory(NVIM_TMPDIR) then
  luv.fs_mkdir(NVIM_TMPDIR, tonumber('755', 8))
end

local TMPDIR = os.getenv('TMPDIR') and os.getenv('TMPDIR') or os.getenv('TEMP')
if not TMPDIR or not is_directory(TMPDIR) then
  TMPDIR = luv.fs_mkdtemp(join_paths(NVIM_TMPDIR, 'tmp.XXXXXXXXXX'))
  luv.os_setenv('TMPDIR', TMPDIR)
end

local function tmpdir_get()
  return TMPDIR
end

local NVIM_LOG_FILE = os.getenv('NVIM_LOG_FILE')
if not NVIM_LOG_FILE or not is_file(NVIM_LOG_FILE) then
  local _, tmpfile = luv.fs_mkstemp(join_paths(tmpdir_get(), 'nvim_log.XXXXXXXXXX'))
  -- NOTE: this isn't thread-safe according to luv's docs
  luv.os_setenv('NVIM_LOG_FILE', tmpfile)
end

luv.os_unsetenv('XDG_DATA_DIRS')
luv.os_unsetenv('NVIM')

fs.join_paths = join_paths
fs.is_file = is_file
fs.is_directory = is_directory
fs.NVIM_TMPDIR = NVIM_TMPDIR

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
