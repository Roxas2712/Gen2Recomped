-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local H=require('tests.harness');local I=require('src.render.ShaderUniformInterface')
local queries=0;local shader={};local record={hook={hasUniform=function(s,name)
 H.eq(s,shader);queries=queries+1;return name=='present'
end}};local variant={shader=shader};local stats={}
H.eq(I.has(record,variant,'present',stats),true)
H.eq(I.has(record,variant,'removed',stats),false)
for i=1,20 do H.eq(I.has(record,variant,'present',stats),true);H.eq(I.has(record,variant,'removed',stats),false)end
H.eq(queries,2,'false and true interfaces are cached');H.eq(stats.interfaceHits,40)
record.hook.hasUniform=function()queries=queries+1;return false end
H.eq(I.has(record,variant,'present',stats),false,'hook replacement invalidates interface metadata')
H.eq(queries,3);H.eq(variant.uniformInterface.count,1)
for i=1,1000 do I.has(record,variant,'name'..i,stats)end
H.eq(variant.uniformInterface.count,256,'metadata bound')
local before=queries;I.has(record,variant,'name1000',stats);H.eq(queries,before+1,'overflow retains native query')
local other={shader=shader};I.has(record,other,'present',stats)
H.check(other.uniformInterface~=variant.uniformInterface,'each linked variant owns its interface')
local opaque={};record.hook.hasUniform=function()queries=queries+1;return opaque end
H.eq(I.has(record,other,'foreign',stats),opaque)
before=queries;H.eq(I.has(record,other,'foreign',stats),opaque)
H.eq(queries,before+1,'opaque hook results keep native queries')
H.eq(other.uniformInterface.count,0,'opaque result is never retained as interface metadata')
H.finish('immutable linked uniform interfaces, negative entries, hook replacement and bounded fallback')
