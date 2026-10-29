-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Performance=require('src.core.Performance')
local oldLove,oldJit,oldEnv,oldFlag=love,jit,os.getenv,Performance.shaderBranchSpecialization
local oldLegacy,oldAlpha=package.loaded['src.render.LegacyShaderCompat'],package.loaded['src.render.AlphaDepthCompat']
package.loaded['src.render.LegacyShaderCompat']=nil;package.loaded['src.render.AlphaDepthCompat']=nil
local data=setmetatable({},{__mode='k'});local methods={};local prototype=newproxy(true)
getmetatable(prototype).__index=methods
local callback;local quiet=false;local actual,gamma=nil,false;local all={};local totalWrites=0
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
function methods:hasUniform(name)
 assert(not data[self].released)
 return data[self].source:find('uniform%s+[%w_]+%s+'..name..'[%s;%[]')~=nil
end
function methods:send(name,...)
 local row=data[self];assert(not row.released);totalWrites=totalWrites+1;row.writes=row.writes+1
 if quiet then return 'native-success',nil,17 end
 local values={...};row.values[name]=row.values[name]or{}
 if name=='arr'then for i,v in ipairs(values)do row.values[name][i]=copy(v)end
 else row.values[name]=copy(values)end
 if callback then local fn=callback;callback=nil;fn(self,name,...)end
 return 'native-success',nil,17
end
local nativeSend=methods.send
function methods:sendColor(...)return nativeSend(self,...)end
function methods:release()data[self].released=true end
local g={getShader=function()return actual end,setShader=function(s)actual=s end,
 getStackDepth=function()return 0 end,getRendererInfo=function()return'Metal'end,isGammaCorrect=function()return gamma end}
function g.newShader(source)
 local s=newproxy(prototype);data[s]={source=source,values={},writes=0};all[#all+1]=s;return s
end
function g.draw()return actual and copy(data[actual].values)end
love={graphics=g,getVersion=function()return 12 end,system={getOS=function()return'OS X'end},
 timer={getTime=os.clock},thread={newChannel=function()
  local value;return{push=function(_,v)value=v end,peek=function()return value end,clear=function()value=nil end,release=function()end}
 end}}
jit={arch='arm64'};Performance.shaderBranchSpecialization=true
os.getenv=function(name)if name=='POKEPORT_SHADER_BRANCHES'then return'1'end;return oldEnv(name)end
local S=assert(loadfile('src/render/ShaderSpecialization.lua'))();T.check(S.install())
local source='uniform float gate;uniform bool lit;uniform float value;uniform vec4 arr[4];uniform mat4 matrix;uniform Image tex;\n'..
 'vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){if(gate>.5&&lit)return c;return vec4(value);}\n/*'..string.rep('x',65536)..'*/'
local shader=g.newShader(source);g.setShader(shader)
shader:send('gate',0);shader:send('lit',true);shader:send('value',7);g.draw()
local cached=actual;T.check(cached~=shader)
local release=S.pauseCompilation(shader);T.eq(type(release),'function')
local before=S.status().compiled;local deferred=S.status().deferredVariantDraws
shader:send('gate',1);local observed=g.draw()
T.eq(actual,shader,'cold key uses the current original shader')
T.eq(observed.value[1],7);T.eq(S.status().compiled,before,'no synchronous variant compilation')
T.eq(S.status().deferredVariantDraws,deferred+1)
shader:send('gate',0);g.draw();T.eq(actual,cached,'already compiled key stays available while paused')
local nested=S.pauseCompilation(shader);T.eq(type(nested),'function')
T.eq(release(),true);T.eq(release(),false,'leases release once')
shader:send('gate',1);g.draw();T.eq(actual,shader,'another consumer still holds its pause')
T.eq(S.status().compiled,before)
T.eq(nested(),true);g.draw();T.check(actual~=shader,'last release reopens optional compilation')
T.eq(S.status().compiled,before+1);T.eq(g.draw().value[1],7)
-- Re-entering the pause never freezes changing native values or array tails.
release=S.pauseCompilation(shader)
shader:send('arr',{1,2,3,4},{5,6,7,8},{9,10,11,12})
shader:send('arr',{33,44,55,66});shader:send('lit',false)
local a,b,c=shader:send('value',19);T.eq(a,'native-success');T.eq(b,nil);T.eq(c,17)
observed=g.draw();T.eq(actual,shader);T.eq(observed.arr[1][1],33);T.eq(observed.arr[3][4],12);T.eq(observed.value[1],19)
-- A second mod/source keeps ordinary compilation policy and method behavior.
local other=g.newShader(source);g.setShader(other);other:send('gate',0);other:send('lit',true);g.draw()
local compiled=S.status().compiled;other:send('gate',1);g.draw()
T.eq(S.status().compiled,compiled+1,'pause does not widen to unrelated sources')
local unqualified=g.newShader('uniform float value;vec4 effect(vec4 c,Image t,vec2 u,vec2 p){return c;}')
T.eq(S.pauseCompilation(unqualified),nil,'unknown/small shader has no optional compiler state')
shader:release();T.eq(S.pauseCompilation(shader),nil,'disabled/released source cannot acquire another lease')
T.eq(release(),true,'existing lease can release after source disable');T.eq(release(),false)
T.check(type(S.status().lastCompileKey)=='string'and S.status().lastCompileSeconds>=0,'bounded compile diagnostics available')
love,jit,os.getenv,Performance.shaderBranchSpecialization=oldLove,oldJit,oldEnv,oldFlag
package.loaded['src.render.LegacyShaderCompat'],package.loaded['src.render.AlphaDepthCompat']=oldLegacy,oldAlpha
T.finish('per-source compilation leases preserve live uniforms, cached variants, ownership and native fallback')
