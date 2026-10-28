-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read a user-selected host file. Windows LuaJIT's io.open uses the ANSI
-- codepage; the native wide API keeps UTF-8 paths, including the user's TEMP
-- directory, independent of that codepage. This never stages or writes data.
local NativeFile = {}
local windowsAPI

local function windowsRead(path)
  local ffi = require('ffi')
  if ffi.os ~= 'Windows' then return nil, 'native Windows reader unavailable' end
  if not windowsAPI then
    ffi.cdef[[
    int __stdcall MultiByteToWideChar(unsigned int, unsigned long, const char *, int, uint16_t *, int);
    void * __stdcall CreateFileW(const uint16_t *, unsigned long, unsigned long, void *, unsigned long, unsigned long, void *);
    int __stdcall GetFileSizeEx(void *, int64_t *);
    int __stdcall ReadFile(void *, void *, unsigned long, unsigned long *, void *);
    int __stdcall CloseHandle(void *);
    unsigned long __stdcall GetLastError(void);
    ]]
    windowsAPI = ffi.load('kernel32')
  end
  local api = windowsAPI
  local n = api.MultiByteToWideChar(65001, 8, path, #path, nil, 0)
  if n == 0 then return nil, 'invalid UTF-8 file path' end
  local wide = ffi.new('uint16_t[?]', n + 1)
  if api.MultiByteToWideChar(65001, 8, path, #path, wide, n) == 0 then
    return nil, 'cannot convert UTF-8 file path'
  end
  -- OPEN_EXISTING, GENERIC_READ, FILE_SHARE_READ: never create/truncate the
  -- chosen file and do not accept a concurrent writer changing its contents.
  local handle = api.CreateFileW(wide, 0x80000000, 1, nil, 3, 0x08000000, nil)
  if handle == ffi.cast('void *', -1) then
    return nil, 'cannot open file (Windows error '..tonumber(api.GetLastError())..')'
  end
  handle = ffi.gc(handle, api.CloseHandle)
  local function read()
    local size = ffi.new('int64_t[1]')
    if api.GetFileSizeEx(handle, size) == 0 then
      return nil, 'cannot measure file (Windows error '..tonumber(api.GetLastError())..')'
    end
    local length = tonumber(size[0])
    if length == 0 then return nil, 'empty file' end
    if length < 0 or length > 2147483647 then return nil, 'file too large for a Lua string' end
    local buffer, count = ffi.new('uint8_t[65536]'), ffi.new('unsigned long[1]')
    local chunks, remaining = {}, length
    while remaining > 0 do
      local wanted = math.min(remaining, 65536)
      if api.ReadFile(handle, buffer, wanted, count, nil) == 0 then
        return nil, 'cannot read file (Windows error '..tonumber(api.GetLastError())..')'
      end
      local got = tonumber(count[0])
      if got == 0 then return nil, 'file ended before its reported size' end
      chunks[#chunks + 1] = ffi.string(buffer, got)
      remaining = remaining - got
    end
    return table.concat(chunks)
  end
  local ok, bytes, why = pcall(read)
  ffi.gc(handle, nil)
  api.CloseHandle(handle)
  if not ok then return nil, bytes end
  return bytes, why
end

function NativeFile.read(path)
  if type(path) ~= 'string' or path == '' or path:find('%z') then
    return nil, 'invalid native file path'
  end
  local osName = love and love.system and love.system.getOS and love.system.getOS()
  if osName == 'Windows' then
    local ok, bytes, why = pcall(windowsRead, path)
    if not ok then return nil, bytes end
    return bytes, why
  end
  local opened, file, why = pcall(io.open, path, 'rb')
  if not opened or not file then return nil, opened and why or file end
  local ok, bytes, err = pcall(file.read, file, '*a')
  pcall(file.close, file)
  if not ok then return nil, bytes end
  if not bytes or bytes == '' then return nil, err or 'empty file' end
  return bytes
end

return NativeFile
