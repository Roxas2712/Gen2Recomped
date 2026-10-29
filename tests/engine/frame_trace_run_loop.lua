-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Execute the actual native run loop without a renderer, sleeping or save data.
local H=require('tests.harness')
local file=assert(io.open('main.lua','rb'));local source=file:read('*a');file:close()
local at=assert(source:find('\nfunction love.run()',1,true))
source=source:sub(at+1)
local previousLove=love
local loaded={}
for _,name in ipairs{'src.core.Logger','src.core.FrameTrace','src.core.FrameProfile'}do loaded[name]=package.loaded[name]end
local function scenario(manualAt,frames,quit)
 local now,writes,updates,quitNow=0,{},0,false
 local logger={warn=function()end,report=function()end,flush=function()end}
 local noop=function()end
 love={timer={getTime=function()return now end,step=function()now=now+.016;return .016 end,sleep=noop},
  window={hasFocus=function()return true end},
  filesystem={createDirectory=function()return true end,write=function(path,data)writes[#writes+1]={path=path,data=data};return true end},
  event={pump=noop,poll=function()
   local sent=false
   return function()if quitNow and not sent then sent=true;return 'quit',0 end end
  end},handlers={}}
 package.loaded['src.core.Logger']=logger
 package.loaded['src.core.FrameTrace']=nil;package.loaded['src.core.FrameProfile']=nil
 local F=require('src.core.FrameTrace');local P=require('src.core.FrameProfile')
 love.update=function()
  updates=updates+1
  if updates==manualAt then P.toggle()end
 end
 local modules={['src.core.FrameTrace']=F,['src.core.Performance']={},
  ['src.core.GCFrameBudget']={configure=noop,beginFrame=noop,idle=noop},
  ['src.core.FrameCap']={focused=true,current=60},
  ['src.core.IdleStream']={idle=function()return noop end},['src.core.Logger']=logger}
 local env=setmetatable({love=love,Game=false,lastLogFlush=0,
  FrameProfile=P,BootTrace={mark=noop,frame=noop},Frames={tick=noop},pacingEnabled=function()return false end,
  os={getenv=function(name)if name=='GEN2_FRAME_TRACE'then return '1'end end},
  require=function(name)return assert(modules[name],'unexpected loop dependency: '..name)end},{__index=_G})
 local chunk
 if setfenv then
  chunk=assert(loadstring(source,'@main.lua:love.run'));setfenv(chunk,env)
 else chunk=assert(load(source,'@main.lua:love.run','t',env))end
 chunk()
 local step=env.love.run()
 for _=1,frames do H.eq(step(),nil,'ordinary loop iteration continues')end
 if quit then quitNow=true;H.eq(step(),0,'quit returns normally')end
 return F,P,writes
end

local F,P,writes=scenario(nil,601,false)
H.eq(F.enabled(),false,'unreplaced startup capture stops at its own limit')
H.eq(#writes,1,'startup capture writes exactly once')
H.eq(require('src.link.Json').decode(writes[1].data).totalFrames,600,'startup limit is unchanged')

F,P,writes=scenario(599,605,false)
H.eq(F.enabled(),true,'old startup deadline cannot stop the F11 replacement')
H.eq(P.enabled(),true,'manual summary profiling remains enabled')
H.eq(#writes,0,'old startup owner cannot publish the manual capture')
H.eq(F.snapshot().totalFrames,6,'manual capture owns only subsequent complete frames')
P.toggle()
H.eq(#writes,1,'manual stop writes its own capture once')
H.eq(require('src.link.Json').decode(writes[1].data).totalFrames,6,'manual output retains its actual frames')

F,P,writes=scenario(nil,2,true)
H.eq(F.enabled(),false,'quitting stops startup tracing')
H.eq(#writes,1,'quitting flushes one bounded trace')
local snapshot=require('src.link.Json').decode(writes[1].data)
H.eq(snapshot.frames[#snapshot.frames].completed,false,'quit frame is explicitly incomplete')
for _,name in ipairs{'src.core.Logger','src.core.FrameTrace','src.core.FrameProfile'}do package.loaded[name]=loaded[name]end
love=previousLove
H.finish('actual run-loop startup/manual trace ownership, automatic limit and quit flush')
