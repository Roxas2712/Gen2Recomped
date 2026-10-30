-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local originalFfi=package.loaded.ffi
local originalSystem=love.system
local originalTimer=love.timer
local attempts,seconds,failures,last,target,removed=0,0,{},0,'previous complete file',0
local fake={cdef=function()end,new=function()return{}end,C={}}
fake.C.MultiByteToWideChar=function(_,_,_,n)return n end
fake.C.MoveFileExW=function(_,_,flags)
  T.eq(flags,1,'replacement stays atomic')
  attempts=attempts+1;last=failures[attempts]or 0
  if last~=0 then T.eq(target,'previous complete file','retry never removes old bytes');return 0 end
  target='new complete file';return 1
end
fake.C.GetLastError=function()return last end
package.loaded.ffi=fake
love.system={getOS=function()return'Windows'end}
love.timer={getTime=function()return seconds end,sleep=function(n)seconds=seconds+n end}
local publish=dofile('src/net/DownloadPublish.lua')
failures={5,32,33};T.check(publish('stage','target',2),'transient locks eventually publish')
T.eq(attempts,4,'access/sharing/lock conflicts each retry')
T.eq(target,'new complete file','successful retry replaces full destination')
attempts,seconds,target,failures=0,0,'previous complete file',{3}
T.eq(publish('stage','target',2),nil,'permanent path error is returned')
T.eq(attempts,1,'permanent error is never retried')
attempts,seconds,target,failures=0,0,'previous complete file',{}
for i=1,100 do failures[i]=5 end
T.eq(publish('stage','target',2),nil,'persistent denial terminates')
T.check(attempts<=50 and seconds<=0.25,'attempt/time budget is bounded')
T.eq(target,'previous complete file','persistent error preserves destination')
attempts,seconds=0,0
T.eq(publish('stage','target',0),nil,'expired download cannot claim a rename')
T.eq(attempts,0,'deadline checked before OS mutation')
attempts,seconds=0,0
T.eq(publish('stage','target',0.01),nil,'shorter request deadline wins')
T.check(seconds<=0.01,'retry cannot spend past request deadline')
package.loaded.ffi=originalFfi;love.system=originalSystem;love.timer=originalTimer
T.finish('Windows atomic download publication retry')
