-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local H=require('tests.harness')
local previousLove=love;local t,writes,clockCalls=0,{},0
love={timer={getTime=function()clockCalls=clockCalls+1;return t end},filesystem={
 createDirectory=function(p)H.eq(p,'performance');return true end,
 write=function(p,data)writes[#writes+1]={p,data};return true end}}
package.loaded['src.core.FrameTrace']=nil
local F=require('src.core.FrameTrace');local J=require('src.link.Json')
H.eq(F.enabled(),false);F.beginFrame(true);F.section('disabled')();F.add('disabled',1);F.endFrame()
H.eq(clockCalls,0,'disabled recorder does not read clock')
F.start({frames=2,events=2});F.setContext('qa-map rain third')
F.beginFrame(true);local outer=F.section('outer');t=.001;local inner=F.section('inner');t=.004;inner();inner();t=.010;outer()
F.add('extra',.002);t=.016;F.endFrame(true)
local s=F.snapshot();H.eq(#s.frames,1);H.eq(s.frames[1].stages.inner.calls,1,'closures close once')
H.eq(s.frames[1].stages.outer.seconds,.010);H.eq(s.frames[1].droppedEvents,1)
H.check(math.abs(s.frames[1].stages.extra.maxStart-.008)<1e-12,'overflow preserves worst span timestamp')
H.eq(s.frames[1].stages.extra.maxEnd,.010)
H.eq(s.frames[1].context,'qa-map rain third');H.eq(s.frames[1].focused,true)
s.frames[1].stages.outer.seconds=99;H.eq(F.snapshot().frames[1].stages.outer.seconds,.010,'snapshot ownership')
F.beginFrame(false);local abandoned=F.section('stale');t=.020;F.beginFrame(true);abandoned()
F.add('invalid',0/0);F.add('invalid',math.huge);F.add('invalid',-1)
F.endFrame(true);s=F.snapshot();H.eq(s.totalFrames,3);H.eq(#s.frames,2)
H.eq(s.frames[1].index,2);H.eq(s.frames[1].completed,false);H.eq(s.frames[1].focused,false)
H.eq(s.frames[2].index,3);H.eq(s.frames[2].stages.stale,nil);H.eq(s.frames[2].stages.invalid,nil)
local live=pcall(F.write,'frame-trace.json');H.eq(live,false,'no disk write during capture')
F.beginFrame(true);local oldEpoch=F.section('epoch');F.start();F.beginFrame(true);oldEpoch();F.endFrame();F.stop()
H.eq(F.snapshot().frames[1].stages.epoch,nil,'restarted capture invalidates old spans')
H.eq(pcall(F.write,'../save.json'),false);H.eq(pcall(F.write,'save/slot.json'),false)
H.eq(#writes,0);H.eq(F.write('qa-frame-trace.json'),true);H.eq(#writes,1)
local decoded=J.decode(writes[1][2]);H.eq(decoded.qualifiedFps,false);H.eq(decoded.overlappingSpans,true)
F.start({frames=1,events=1});F.beginFrame(true)
for i=1,1000 do F.add('label'..i,0)end
F.endFrame();F.stop();s=F.snapshot();H.eq(#s.frames[1].events,1)
local n=0;for _ in pairs(s.frames[1].stages)do n=n+1 end
H.eq(n,256);H.eq(s.frames[1].droppedLabels,744);H.eq(s.frames[1].droppedEvents,255)
-- Existing section callers feed the recorder even with summary reporting off.
local logger=package.loaded['src.core.Logger'];package.loaded['src.core.Logger']={warn=function()end}
package.loaded['src.core.FrameProfile']=nil;local P=require('src.core.FrameProfile')
F.start();F.beginFrame(true);local close=P.section('engine update');t=t+.003;close();P.add('hook self',.001)
F.endFrame();F.stop();s=F.snapshot();H.eq(s.frames[1].stages['engine update'].calls,1)
H.eq(s.frames[1].stages['hook self'].seconds,.001);H.eq(P.enabled(),false)
F.start();F.beginFrame(true)
local a,b,c,d=P.wrap('wrapped trace only',function(x,y)t=t+.002;return x,nil,y,false end,7,9)
H.eq(a,7);H.eq(b,nil);H.eq(c,9);H.eq(d,false)
F.endFrame();F.stop();s=F.snapshot()
H.eq(s.frames[1].stages['wrapped trace only'].calls,1,'wrap feeds trace with summary off')
H.check(math.abs(s.frames[1].stages['wrapped trace only'].seconds-.002)<1e-12)
local before=clockCalls
H.eq(P.wrap('disabled wrap',function(x)return x end,17),17)
H.eq(clockCalls,before,'disabled wrap does not read clock')
H.eq(P.toggle(),true);H.eq(F.enabled(),true)
F.beginFrame(true);P.section('interactive capture')();F.endFrame()
H.eq(P.toggle(),false);H.eq(F.enabled(),false);H.eq(#writes,2)
H.eq(J.decode(writes[2][2]).frames[1].stages['interactive capture'].calls,1)
package.loaded['src.core.Logger']=logger;love=previousLove
H.finish('bounded per-frame wall/submission trace, ownership, inactive path and profile bridge')
