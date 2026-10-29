-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local H=require('tests.harness');local B=assert(loadfile('tools/runtime_bottleneck.lua'))()
local callback,mode,stops,t,frame=nil,nil,0,0,0
local p={start=function(m,f)mode=m;callback=f end,stop=function()stops=stops+1 end,
 dumpstack=function(_,fmt)
  if fmt=='pl'then return'actor.lua:'..frame end
  if fmt=='pF;'then return'actor;renderer' end
  return'actor|renderer|actor'
 end}
local o={frames=4,keys=2,profiler=p,clock=function()return t end,
 wait=function(n)H.eq(n,1);frame=frame+1;t=t+frame*.01;callback(nil,2,'N');callback(nil,1,'C')end,
 observe=function()return{focused=true,drawMs=3}end}
local r=B.capture(o)
H.eq(mode,'fi5');H.eq(stops,1);H.eq(r.qualifiedFps,false);H.eq(r.samples,12)
H.eq(#r.frames,4);H.eq(r.frames[4].index,4);H.check(math.abs(r.frames[4].ms-40)<1e-8)
H.eq(#r.self,2);H.eq(r.overflow.self,6,'bounded self keys retain discarded sample count')
H.eq(r.inclusive[1].hits,12,'recursive frames count once per sample')
H.eq(r.inclusive[2].hits,12);H.eq(r.stacks[1].hits,12)
H.eq(r.states.N,8);H.eq(r.states.C,4);H.eq(r.worstFrames[1].index,4)
-- Capture failures stop the sampler and preserve the original failure.
o.observe=function()error('fixture observer failed')end
local ok,why=pcall(B.capture,o);H.eq(ok,false);H.check(tostring(why):find('fixture observer failed',1,true)~=nil);H.eq(stops,2)
-- No samples is useful evidence: never manufacture a CPU/GPU diagnosis.
o.frames=1;o.wait=function()t=t+.02 end;o.observe=function()return{}end
r=B.capture(o);H.eq(r.samples,0);H.eq(#r.self,0);H.eq(#r.frames,1);H.eq(stops,3)
o.frames=600;o.seconds=1;o.wait=function()t=t+.6 end
r=B.capture(o);H.eq(#r.frames,2);H.eq(r.wallLimitReached,true,'slow capture retains completed frames at wall bound')
H.finish('bounded runtime sampling, per-frame outliers, recursion, overflow and error cleanup')
