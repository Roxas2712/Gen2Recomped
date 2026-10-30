-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read a user-selected host file. Windows LuaJIT's io.open uses the ANSI
-- codepage; the native wide API keeps UTF-8 paths, including the user's TEMP
-- directory, independent of that codepage. This never stages or writes data.
local NativeFile = {}
local windowsAPI

local function windowsBindings()
  local ffi = require('ffi')
  if ffi.os ~= 'Windows' then return nil, 'native Windows reader unavailable' end
  if not windowsAPI then
    ffi.cdef[[
    int __stdcall MultiByteToWideChar(unsigned int, unsigned long, const char *, int, uint16_t *, int);
    void * __stdcall CreateFileW(const uint16_t *, unsigned long, unsigned long, void *, unsigned long, unsigned long, void *);
    int __stdcall GetFileSizeEx(void *, int64_t *);
    int __stdcall ReadFile(void *, void *, unsigned long, unsigned long *, void *);
    int __stdcall WriteFile(void *,const void *,unsigned long,unsigned long *,void *);
    int __stdcall FlushFileBuffers(void *);
    int __stdcall MoveFileExW(const uint16_t *,const uint16_t *,unsigned long);
    int __stdcall CloseHandle(void *);
    unsigned long __stdcall GetLastError(void);
    ]]
    windowsAPI = ffi.load('kernel32')
  end
  return ffi,windowsAPI
end

local function windowsRead(path)
  local ffi,api=windowsBindings()
  if not ffi then return nil,api end
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

-- Bounded, read-only input for cooperative importers. Keep the old whole-file
-- read contract above; callers of this API own and close the returned handle.
function NativeFile.openRead(path)
  if type(path)~='string' or path=='' or path:find('%z')then return nil,'invalid native file path'end
  local osName=love and love.system and love.system.getOS and love.system.getOS()
  if osName~='Windows'then
    local file,why=io.open(path,'rb');if not file then return nil,why end
    local size=file:seek('end')
    if not size or not file:seek('set',0)then file:close();return nil,'cannot measure/rewind native file'end
    return file,size
  end
  local called,stream,size=pcall(function()
    local ffi,api=windowsBindings();if not ffi then return nil,api end
    local n=api.MultiByteToWideChar(65001,8,path,#path,nil,0)
    if n==0 then return nil,'invalid UTF-8 file path'end
    local wide=ffi.new('uint16_t[?]',n+1)
    if api.MultiByteToWideChar(65001,8,path,#path,wide,n)==0 then return nil,'cannot convert UTF-8 file path'end
    local handle=api.CreateFileW(wide,0x80000000,1,nil,3,0x08000000,nil)
    if handle==ffi.cast('void *',-1)then return nil,'cannot open native file (Windows error '..tonumber(api.GetLastError())..')'end
    handle=ffi.gc(handle,api.CloseHandle)
    local length=ffi.new('int64_t[1]')
    local measured=api.GetFileSizeEx(handle,length)~=0
    local bytes=tonumber(length[0]);local closed=false
    local file={}
    function file:close()
      if closed then return true end
      if api.CloseHandle(handle)==0 then return nil,'cannot close native file'end
      closed=true;ffi.gc(handle,nil);return true
    end
    if not measured or bytes<0 then file:close();return nil,'cannot measure native file'end
    function file:read(amount)
      if closed then return nil,'native file is closed'end
      if type(amount)~='number' or amount<1 or amount>4*1024*1024 or amount%1~=0 then return nil,'invalid stream chunk size'end
      local buffer,count=ffi.new('uint8_t[?]',amount),ffi.new('unsigned long[1]')
      if api.ReadFile(handle,buffer,amount,count,nil)==0 then return nil,'cannot read native file (Windows error '..tonumber(api.GetLastError())..')'end
      local got=tonumber(count[0]);return ffi.string(buffer,got),got
    end
    return file,bytes
  end)
  if not called then return nil,stream end
  return stream,size
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

local writeSerial=0
function NativeFile.atomicWrite(path,data)
  if type(path)~='string'or path==''or path:find('%z')or type(data)~='string'then return nil,'invalid native output'end
  local ffi,api=windowsBindings();if not ffi then return nil,api end
  local function wide(value)
    local n=api.MultiByteToWideChar(65001,8,value,#value,nil,0)
    if n==0 then return nil end
    local result=ffi.new('uint16_t[?]',n+1)
    if api.MultiByteToWideChar(65001,8,value,#value,result,n)==0 then return nil end
    return result
  end
  local target=wide(path);if not target then return nil,'invalid UTF-8 output path'end
  local pending,handle
  for _=1,100 do
    writeSerial=writeSerial+1;pending=wide(path..'.pending-'..os.time()..'-'..writeSerial)
    if not pending then return nil,'invalid UTF-8 recovery path'end
    handle=api.CreateFileW(pending,0x40000000,0,nil,1,0x80,nil)
    if handle~=ffi.cast('void *',-1)then break end
    handle=nil
  end
  if not handle then return nil,'Could not create a new recovery file; previous saves were retained.'end
  local offset=0;local count=ffi.new('unsigned long[1]');local bytes=ffi.cast('const uint8_t*',data)
  local ok=true
  while offset<#data do
    local size=math.min(#data-offset,65536)
    if api.WriteFile(handle,bytes+offset,size,count,nil)==0 or count[0]==0 then ok=false;break end
    offset=offset+tonumber(count[0])
  end
  if ok then ok=api.FlushFileBuffers(handle)~=0 end
  local closed=api.CloseHandle(handle)~=0
  if not ok or not closed then return nil,'Could not commit the recovery file; previous saves were retained.'end
  if api.MoveFileExW(pending,target,1+8)==0 then return nil,'Could not replace the save; previous data and the recovery file were retained.'end
  return true
end

return NativeFile
