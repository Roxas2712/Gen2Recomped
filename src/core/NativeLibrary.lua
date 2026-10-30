-- Load native modules and their adjacent dependencies through Unicode APIs.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={};local retained={}
function M.load(path)
 local ffi=require('ffi');assert(type(path)=='string'and not path:find('%z'),'Invalid native library path')
 if ffi.os=='Windows'and not retained[path]then
  ffi.cdef[[
   int __stdcall MultiByteToWideChar(unsigned int,unsigned long,const char*,int,uint16_t*,int);
   void* __stdcall LoadLibraryExW(const uint16_t*,void*,unsigned long);
   unsigned long __stdcall GetLastError(void);
  ]]
  local kernel=ffi.load('kernel32')
  local n=kernel.MultiByteToWideChar(65001,8,path,#path,nil,0);assert(n>0,'Invalid UTF-8 native library path')
  local wide=ffi.new('uint16_t[?]',n+1);assert(kernel.MultiByteToWideChar(65001,8,path,#path,wide,n)==n)
  local handle=kernel.LoadLibraryExW(wide,nil,0x100+0x1000)
  assert(handle~=nil,'Could not load the native library (Windows error '..tonumber(kernel.GetLastError())..')')
  retained[path]=handle
 end
 return ffi.load(path)
end
return M
