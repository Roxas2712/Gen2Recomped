local T=require("tests.harness")
local now=0
local nativePresent=function() now=now+0.001;return nil,"native-result" end
love={timer={getTime=function()return now end},graphics={present=nativePresent}}
local FP=require("src.core.FrameProfile")
local section,add=FP.section,FP.add
local measure=require("tools.performance_baseline_meter")
T.check(not pcall(measure,{},59),"short intervals cannot be published as a baseline")
local co=coroutine.create(function()
  return measure({},60,function()
    local started=now
    coroutine.yield()
    return {{crossingStart=started,crossingEnd=now}}
  end,function()return now<30 and "high" or "low",true end)
end)
T.check(coroutine.resume(co),"meter starts as a frame driver")
local result
for frame=1,4 do
  local start=now
  local close=FP.section("world: tiles")
  now=now+0.002;close()
  FP.add("world: FX",0.003)
  FP.bake("tiles.gen2");FP.bake("tiles.gen2")
  if frame==2 then FP.reset() end -- native 120-frame report windows reset their own counters
  now=start+({20,10,30,20})[frame]-0.001
  local function results(...)
    T.eq(select("#",...),2,"present return arity is preserved")
    local a,b=...
    T.eq(a,nil,"present leading nil is preserved")
    T.eq(b,"native-result","present trailing value is preserved")
  end
  results(love.graphics.present())
  local ok,value=coroutine.resume(co)
  T.check(ok,"frame observation resumes")
  if coroutine.status(co)=="dead" then result=value end
end
T.eq(result.frames,3,"first partial frame is excluded")
T.check(math.abs(result.seconds-60)<1e-8,"elapsed time spans actual presentation boundaries")
T.check(math.abs(result.frame.avgMs-20000)<1e-8,"average interval uses completed frames")
T.check(math.abs(result.frame.maxMs-30000)<1e-8,"whole-scene maximum includes the later slow frame")
T.check(math.abs(result.walks[1].maxFrameMs-10000)<1e-8,"crossing maximum excludes the unrelated next frame")
T.eq(result.walks[1].windowFrames,1,"crossing ends at the already presented native frame")
T.eq(#result.tierTrace,2,"tier changes are observed without altering the controller")
T.eq(result.tierTrace[2].seconds,10,"tier timestamps are relative to measurement start")
T.check(math.abs(result.sections["world: tiles"].avgMsPerFrame-2)<1e-8,"section average includes each measured frame once")
T.check(math.abs(result.sections["world: FX"].maxMsPerFrame-3)<1e-8,"direct profiler deposits contribute to frame maxima")
T.eq(result.bakes["tiles.gen2"].total,6,"interval bake totals survive native profiler-window resets")
T.eq(result.bakes["tiles.gen2"].peakPerFrame,2,"bake peaks use rendered-frame boundaries")
T.check(love.graphics.present==nativePresent and FP.section==section and FP.add==add,"native functions are restored")
T.eq(FP.enabled(),false,"previous profiler state is restored")
T.finish("baseline statistics and transparent presentation instrumentation")
