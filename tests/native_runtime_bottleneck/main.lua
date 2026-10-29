-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Small native-VM qualification before attaching a profiler to a whole game.
local task
local function work()
 local n=0;for i=1,100000 do n=n+math.sin(i)end
 return n
end
function love.load()
 task=coroutine.create(function()
  local capture=assert(loadfile(assert(os.getenv('QA_BOTTLENECK_TOOL'))))().capture
  local r=capture{profiler=require('jit.profile'),clock=love.timer.getTime,frames=40,
   wait=function()coroutine.yield()end,observe=function()return{qaOnly=true}end}
  assert(#r.frames==40 and r.samples>0,'native VM produced no usable capture')
  assert(#r.self>0 and #r.stacks>0 and r.qualifiedFps==false)
  local before=r.samples;work();assert(r.samples==before,'sampler continued after capture')
  print('NATIVE_RUNTIME_BOTTLENECK_PASS',#r.frames,r.samples,r.samplingIntervalMs)
  love.event.quit(0)
 end)
end
function love.update()
 work()
 if coroutine.status(task)~='dead'then
  local ok,why=coroutine.resume(task)
  if not ok then print('NATIVE_RUNTIME_BOTTLENECK_FAIL',why);love.event.quit(1)end
 end
end
