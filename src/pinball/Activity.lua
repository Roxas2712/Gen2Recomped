-- Keep an active audio/video consumer out of macOS App Nap. By Roxas2712.
-- The activity permits idle system sleep and ends on pause, finish or close.
local M={}
function M.acquire()
 local lease={active=false}
 function lease:release()
  if self.closed then return end;self.closed=true
  if self.finish then pcall(self.finish);self.finish=nil end
  self.active=false
 end
 if not(love and love.system and love.system.getOS and love.system.getOS()=='OS X')then return lease end
 local ok,why=pcall(function()
  local ffi=require('ffi')
  ffi.cdef[[void* objc_getClass(const char*);void* sel_registerName(const char*);void objc_msgSend(void);
   void* pthread_self(void);int pthread_get_qos_class_np(void*,unsigned int*,int*);
   int pthread_set_qos_class_self_np(unsigned int,int);]]
  local objc=ffi.load('/usr/lib/libobjc.A.dylib')
  local foundation=ffi.load('/System/Library/Frameworks/Foundation.framework/Foundation')
  local send=ffi.cast('void*(*)(void*,void*)',objc.objc_msgSend)
  local argument=ffi.cast('void(*)(void*,void*,void*)',objc.objc_msgSend)
  local string=ffi.cast('void*(*)(void*,void*,const char*)',objc.objc_msgSend)
  local begin=ffi.cast('void*(*)(void*,void*,uint64_t,void*)',objc.objc_msgSend)
  local sel=objc.sel_registerName
  local process=send(objc.objc_getClass('NSProcessInfo'),sel('processInfo'))
  local reason=string(objc.objc_getClass('NSString'),sel('stringWithUTF8String:'),'RetroRecomped native audio and live video')
  -- NSActivityLatencyCritical | NSActivityUserInitiatedAllowingIdleSystemSleep.
  -- Constants are from the platform NSProcessInfo.h, with no display-wake flag.
  local token=begin(process,sel('beginActivityWithOptions:reason:'),0xFF00EFFFFF,reason)
  if token==nil then return end
  send(token,sel('retain'))
  local thread=ffi.C.pthread_self();local qos=ffi.new('unsigned int[1]');local relative=ffi.new('int[1]')
  local queried=ffi.C.pthread_get_qos_class_np(thread,qos,relative)==0
  local priority=queried and tonumber(qos[0])or 0
  local boosted=priority>0 and ffi.C.pthread_set_qos_class_self_np(33,0)==0
  lease.active=true;lease.priorityBefore=priority
  lease.finish=function()
   argument(process,sel('endActivity:'),token);send(token,sel('release'))
   if boosted and ffi.C.pthread_self()==thread then ffi.C.pthread_set_qos_class_self_np(priority,relative[0])end
   foundation=nil
  end
 end)
 if not ok then lease.error=tostring(why)end
 return lease
end
return M
