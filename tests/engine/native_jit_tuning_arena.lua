-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local savedJit,savedArena,savedGetenv=jit,package.loaded['src.core.JitArena'],os.getenv
local received
jit={status=function()return true end,opt={start=function(...)received={...}end}}
package.loaded['src.core.JitArena']={status={applied=true,areaKiB=16384,maxCodeKiB=16384,maxTraces=8192}}
local function policy(value)
 os.getenv=function(key)if key=='POKEPORT_JIT_OPT'then return value end return savedGetenv(key)end
 return assert(loadfile('src/core/JitTuning.lua'))()
end
local default=policy(nil);local applied=default.apply()
local values={};for _,item in ipairs(received)do local k,v=item:match('^(%w+)=(%d+)$');values[k]=tonumber(v)end
T.eq(values.sizemcode,16384,'late tuning keeps the early area size')
T.eq(values.maxmcode,16384,'late tuning keeps the matching total budget')
T.eq(values.maxtrace,8192,'late tuning keeps the qualified trace slots')
T.eq(values.maxrecord,8000,'additional recorder tuning is retained')
T.eq(default.DEFAULT[5],'sizemcode=64','shared worker defaults are not mutated')
T.eq(default.apply(),applied,'late tuning remains idempotent')
received=nil;T.eq(policy('0').apply(),false);T.eq(received,nil,'explicit OFF stays inert')
local custom=policy('maxtrace=2000,hotloop=100').apply()
T.eq(custom[1],'maxtrace=2000');T.eq(custom[2],'hotloop=100','explicit policy retains priority')
local explicit=policy(nil).apply({'maxtrace=2100'})
T.eq(explicit[1],'maxtrace=2100','explicit arguments retain priority')
jit,package.loaded['src.core.JitArena'],os.getenv=savedJit,savedArena,savedGetenv
T.finish('native early arena and later tuning ownership')
