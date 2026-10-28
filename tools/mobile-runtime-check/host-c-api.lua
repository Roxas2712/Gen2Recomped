-- Enter the actual app's C API through a statically compiled native closure.
return function(capacity, platform)
  local ffi = require('ffi')
  ffi.cdef[[int roxas_runtime_capi_check(int capacity);]]
  local api = platform == 'android' and ffi.load('love') or ffi.C
  assert(api.roxas_runtime_capi_check(capacity) == 0, 'actual host native C API gate failed')
  local data = ffi.new('double[2]', {2.25, .5})
  assert(data[0] + data[1] == 2.75, 'actual host FFI data layout failed')
end
