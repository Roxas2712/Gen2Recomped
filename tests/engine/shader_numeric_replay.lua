-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local savedLove,savedJit,savedEnv=love,jit,os.getenv
local savedLegacy=package.loaded['src.render.LegacyShaderCompat'];package.loaded['src.render.LegacyShaderCompat']=nil
local actual,draws=nil,{}
local data=setmetatable({},{__mode='k'});local methods={}
local prototype=newproxy(true);getmetatable(prototype).__index=methods
local function copy(v)
 if type(v)~='table'then return v end
 local r={};for k,a in pairs(v)do r[k]=copy(a)end;return r
end
function methods.hasUniform(self,name)assert(not data[self].released);return data[self].names[name]or false end
function methods.send(self,name,...)
 local d=assert(data[self]);assert(not d.released and d.names[name],'native validation')
 if name=='amount'and type((...))~='number'then error('native numeric validation')end
 local args={n=select('#',...),...};d.writes[name]=(d.writes[name]or 0)+1
 local bank=d.values[name]or{};d.values[name]=bank
 local first=type(args[1])=='string'and 2 or 1
 bank.layout=first==2 and args[1]or nil
 for i=first,args.n do bank[i-first+1]=copy(args[i])end
end
methods.sendColor=methods.send
function methods.release(self)data[self].released=true end
local function compile(source)
 local shader=newproxy(prototype);local names={}
 for name in source:gmatch('uniform%s+[%w_]+%s+([%w_]+)')do names[name]=true end
 data[shader]={names=names,values={},writes={}};return shader
end
local g={newShader=compile,setShader=function(sh)actual=sh end,getShader=function()return actual end,
 getStackDepth=function()return 0 end,getRendererInfo=function()return'Metal'end,isGammaCorrect=function()return false end,
 draw=function()draws[#draws+1]={shader=actual,values=copy(data[actual].values)}end}
love={graphics=g,getVersion=function()return 12 end,system={getOS=function()return'OS X'end},timer={getTime=function()return 0 end},thread={newChannel=function()
 local value;return{push=function(_,v)value=v end,peek=function()return value end}
end}}
jit={arch='arm64'};os.getenv=function(n)if n=='POKEPORT_SHADER_BRANCHES'then return'1'end;return savedEnv(n)end
local S=assert(loadfile('src/render/ShaderSpecialization.lua'))();S.deferInactiveNumeric=true;T.check(S.install())
local source='uniform float gate;uniform float amount;uniform float values[4];uniform mat4 matrix;uniform Image tex;vec4 effect(){if(gate>.5)return vec4(amount);return vec4(values[0]);}\n/*'..string.rep('x',65536)..'*/'
local original=g.newShader(source);original:send('amount',1);original:send('gate',0);g.setShader(original);g.draw()
local a=actual;T.check(a~=original,'first optional program')
original:send('gate',1);g.draw();local b=actual;T.check(b~=a and b~=original,'second optional program')
local oldA=data[a].writes.amount or 0;local oldB=data[b].writes.amount or 0
original:send('amount',2)
T.eq(data[a].writes.amount or 0,oldA,'inactive numeric remains pending')
T.eq(data[b].writes.amount,oldB+1,'active program stays eager')
original:send('values',11,22,33,44);original:send('values',55,66)
local matrix={1,2,3,4};original:send('matrix','row',matrix);matrix[1]=999
original:send('gate',0);g.draw()
T.eq(data[a].values.amount[1],2,'pending number visible before reuse')
T.eq(table.concat(data[a].values.values,','),'55,66,33,44','retained array tail replayed')
T.eq(data[a].values.matrix.layout,'row');T.eq(data[a].values.matrix[1][1],1,'caller matrix detached')
local texture=newproxy(true);getmetatable(texture).__index={typeOf=function(_,name)return name=='Texture'end,getDimensions=function()return 1,1 end};original:send('tex',texture)
T.eq(data[a].values.tex[1],texture);T.eq(data[b].values.tex[1],texture,'inactive texture remains eager')
-- Disabling the candidate still settles a previously pending bank on reuse.
original:send('amount',3);S.deferInactiveNumeric=false;original:send('gate',1);g.draw();T.eq(data[b].values.amount[1],3)
S.deferInactiveNumeric=true;original:send('amount',4)
-- A foreign variant setter is ordered after all deferred source writes.
a:send('amount',99);T.eq(data[a].values.amount[1],99)
original:send('gate',0);g.draw();T.eq(data[a].values.amount[1],99,'foreign override is not overwritten by old pending data')
oldB=data[b].writes.amount;original:send('amount',5)
T.eq(data[b].writes.amount,oldB+1,'foreign owner permanently retains eager propagation')
local before=data[original].values.amount[1];T.check(not pcall(methods.send,original,'amount',{}));T.eq(data[original].values.amount[1],before,'failed native validation remains atomic')
local status=S.status();T.check(status.numericReplayWrites>0 and status.deferredNumericUpdates>0,'actual adapter paths exercised')
-- Pure snapshot classification rejects every resource/opaque tail.
local N=require('src.render.NumericUniformReplay')
T.check(N.numericBank({{n=2,'column',{1,2,3,4}}}))
T.check(not N.numericBank({{n=1,{resource={texture}}}}))
T.check(not N.numericBank({{n=1,{[2]=1}}}))
T.check(not N.numericBank({{n=1,setmetatable({1},{})}}))
love,jit,os.getenv=savedLove,savedJit,savedEnv;package.loaded['src.render.LegacyShaderCompat']=savedLegacy
T.finish('deferred numeric shader banks, array tails, textures and foreign aliases')
