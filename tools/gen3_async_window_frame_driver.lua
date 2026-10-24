-- OpenGL deferred presentation: inspect the image actually handed to Cocoa,
-- without enabling synchronous Frame.observe. Verify bounded frame order and
-- full scene pixels across movement, capture, resize and map return.
return function(game)
local U=require("tests.drivers.util")
local Json=require("src.link.Json")
local Frame=require("src.render.WindowFrame")
Frame.shutdown()
local Surface=require("src.render.MacWindowSurface")
local create=Surface.createIfUndefined
local version=assert(os.getenv("POKEPORT_VERSION"))
local out=assert(os.getenv("PALETTE_GPU_OUT"))
local identity=assert(os.getenv("POKEPORT_IDENTITY"))
local stampPeriod=tonumber(os.getenv("POKEPORT_TEST_STAMP_PERIOD")) or 1
assert(stampPeriod==1 or stampPeriod==4,"unsupported test stamp period")
local function stamp(frame)return math.floor(frame/stampPeriod)end
assert(identity:match("^gen2%-palette%-gpu%-"))
assert(love.filesystem.getIdentity()==identity)
local renderer,api,vendor,device=love.graphics.getRendererInfo()
local major,minor,revision=love.getVersion()
local report={game=version,gpu={renderer=renderer,version=api,vendor=vendor,device=device},
  runtime={major=major,minor=minor,revision=revision},checks=0,phases={},screenshots={},
  framesChecked=0,blankFrames=0,staleFrames=0,retries=0,stampPeriod=stampPeriod,imageReuses=0}
local function write(path,value)
  local f=assert(io.open(path,"w"));f:write(Json.encode(value));f:close()
end
local function check(ok,message)
  assert(ok,message);report.checks=report.checks+1
end
local count=0
local originalDraw=love.draw
love.draw=function()
  originalDraw()
  count=count+1
  -- A fresh binary frame number in saturated colours survives OS colour
  -- profiles. It also distinguishes current pixels from cached good images.
  local g=love.graphics
  g.push("all");g.setCanvas();g.origin();g.setShader();g.setScissor()
  g.setBlendMode("replace","premultiplied")
  for bit=0,31 do
    local one=math.floor(stamp(count)/2^bit)%2==1
    g.setColor(one and 1 or 0,one and 0 or 1,0,1)
    g.rectangle("fill",bit*2,0,2,3)
  end
  g.pop()
end
local phase
local function inspect(data,info)
  if not phase then return end
  local bytes=data:getString()
  local width,height=data:getDimensions()
  local ww,wh=love.graphics.getDimensions()
  local dpi=width/ww
  local decoded=0
  for bit=0,31 do
    local x,y=math.floor((bit*2+1)*dpi),math.floor(dpi)
    local at=(y*width+x)*4
    local red,green=bytes:byte(at+1,at+2)
    check((red>240 and green<15) or (green>240 and red<15),"invalid frame-number marker")
    if red>240 then decoded=decoded+2^bit end
  end
  local latency=info.latencyFrames or 0
  check(latency==0 or latency==1,"presentation latency bounded to one frame")
  local expected=stamp(count-latency)
  if decoded~=expected then report.staleFrames=report.staleFrames+1 end
  check(decoded==expected,"presented image belongs to expected stream frame")
  report.deferredFrames=(report.deferredFrames or 0)+(latency==1 and 1 or 0)
  report.currentFrames=(report.currentFrames or 0)+(latency==0 and 1 or 0)
  local colours,n={},0
  for y=math.floor(height*.2),math.floor(height*.7),math.max(1,math.floor(height/60)) do
    for x=math.floor(width*.2),math.floor(width*.8),math.max(1,math.floor(width/60)) do
      local at=(y*width+x)*4;local rgb=bytes:sub(at+1,at+3)
      if not colours[rgb] then colours[rgb]=true;n=n+1 end
    end
  end
  if n<16 then report.blankFrames=report.blankFrames+1 end
  check(n>=16,"blank game frame; warning text and marker are excluded")
  check(info.mode=="metal-frame" or info.mode=="opengl-cocoa-frame" or info.mode=="direct",
    "unknown presentation path")
  phase.frames=phase.frames+1
  phase.firstStamp=phase.firstStamp or decoded
  phase.lastStamp=decoded;phase.mode=info.mode
  report.framesChecked=report.framesChecked+1
end
Surface.createIfUndefined=function(...)
  local bridge=assert(create(...),"test requires the macOS OpenGL recovery")
  local present=bridge.present
  bridge.present=function(self,data,...)
    inspect(data,Frame.info())
    local previous=self.lastData
    present(self,data,...)
    if phase and previous and self.lastData==previous then report.imageReuses=report.imageReuses+1 end
  end
  return bridge
end

local function observe(tag,frames)
  U.wait(60) -- normal map-entry fade/script setup is outside steady state
  phase={name=tag,frames=0,map=game.overworld.map.id}
  local started=love.timer.getTime()
  while phase.frames<frames do
    U.wait(1)
    assert(love.timer.getTime()-started<90,"frame observation timed out")
  end
  report.phases[#report.phases+1]=phase
  local name=version.."-"..tag..".png"
  check(U.shot(game,out.."/"..name),"complete-frame capture was not written")
  report.screenshots[#report.screenshots+1]=name
  if os.getenv("POKEPORT_OS_WINDOW_PROOF")=="1" then
    local ffi=require("ffi");ffi.cdef[[int getpid(void);]]
    local threshold=stamp(count)
    U.wait(5) -- let Core Animation commit; never replace a rejected capture
    local ww,wh=love.graphics.getDimensions()
    local window=assert(require("src.render.MacWindowSurface").windowNumber())
    write(out.."/window-request.json",{phase=tag,window=window,pid=tonumber(ffi.C.getpid()),minimumStamp=threshold,
      logicalWidth=ww,logicalHeight=wh,frame=Frame.info()})
    local done=out.."/window-"..tag..".ok"
    local at=love.timer.getTime()
    while true do
      local file=io.open(done,"r")
      if file then file:close();break end
      assert(love.timer.getTime()-at<30,"own-window OS capture was not acknowledged")
      U.wait(1)
    end
  end
  print("[window-frames] "..tag.." "..phase.frames.." frames "..phase.mode)
  phase=nil
  write(out.."/gpu.json",report)
end

local emerald=version=="emerald"
local target=emerald and "MAP_G26_N21" or "MAP_G03_N00"
local x,y=emerald and 10 or 11,emerald and 5 or 11
U.teleport(game,target,x,y,"down")
observe("initial-map",180)
local other=emerald and "MAP_G26_N18" or "MAP_G04_N01"
U.teleport(game,other,emerald and 11 or 6,emerald and 10 or 6,"down")
observe("second-map",120)
local world=game.overworld
local px,py=world.player.px,world.player.py
U.hold(game,emerald and "down" or "left",20);U.wait(5)
check(world.player.px~=px or world.player.py~=py,"native movement failed")
report.movement=true
local ww,wh,flags=love.window.getMode()
check(love.window.setMode(ww+80,wh+60,flags),"resize failed")
observe("resized",120)
U.teleport(game,target,x,y,"down")
observe("map-return",180)
check(world.map.id==target,"map return failed")
check(report.blankFrames==0 and report.staleFrames==0,"frame stability failed")
check(report.deferredFrames>=600,"ordinary frames must exercise async pipeline")
check(report.currentFrames>=4,"captures must exercise current-frame synchronization")
check(Frame.info().pendingReadbacks<=1,"only one request may remain pending")
if stampPeriod>1 then check(report.imageReuses>=10,"unchanged real game frames must reuse immutable image")end
Frame.shutdown();Surface.createIfUndefined=create
love.draw=originalDraw
report.mapReturn=true;report.pass=true
write(out.."/gpu.json",report)
print("[window-frames] PASS "..version.." "..report.framesChecked.." frames")
end
