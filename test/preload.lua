-- Modules loaded here will not be cleared and reloaded by Busted.
-- See #2082, Olivine-Labs/busted#62 and Olivine-Labs/busted#643

local test_type

for _, value in pairs(_G.arg) do
  if value:match 'IS_FUNCTIONAL_TEST' then
    test_type = 'functional'
  elseif value:match 'IS_UNIT_TEST' then
    test_type = 'unit'
  elseif value:match 'IS_BENCHMARK_TEST' then
    test_type = 'benchmark'
  end
end

-- TODO(kylo252): is this useful?
if os.getenv('DEBUG_TEST') then
  print('>>> detected test_type: ' .. test_type)
end

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
