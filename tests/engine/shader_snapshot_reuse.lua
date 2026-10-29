-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Performance=require('src.core.Performance')
local oldLove,oldJit,oldEnv,oldFlag=love,jit,os.getenv,Performance.shaderBranchSpecialization
local oldLegacy,oldAlpha=package.loaded['src.render.LegacyShaderCompat'],package.loaded['src.render.AlphaDepthCompat']
package.loaded['src.render.LegacyShaderCompat']=nil;package.loaded['src.render.AlphaDepthCompat']=nil
local data=setmetatable({},{__mode='k'});local methods={};local prototype=newproxy(true)
getmetatable(prototype).__index=methods
local quiet=false;local actual,gamma=nil,false;local all={};local totalWrites=0
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
S.recycleSnapshots=true
local function check(condition,message)T.check(condition,message)end
local shader=g.newShader(source);g.setShader(shader)
shader:send('gate',0);shader:send('lit',true);g.draw()
-- Differential oracle: compare the native original and selected variant after
-- changing nested shapes, array prefixes, layouts and caller-owned tables.
local function equal(a,b)
 if type(a)~='table'or type(b)~='table'then return a==b or a~=a and b~=b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function compare()
 local observed=g.draw()
 for name,values in pairs(data[shader].values)do
  if actual:hasUniform(name)then check(equal(observed[name],values),'native/variant value: '..name)end
 end
end
for i=1,120 do
 local vectors={};for j=1,1+i%4 do vectors[j]={i,j,i+j,-i}end
 shader:send('arr',unpack(vectors));compare()
 vectors[1][1]=-1000
 shader:send('gate',i%2);compare() -- replay must not read mutated caller memory
 local m={};for j=1,16 do m[j]=j+i end
 shader:send('matrix',i%2==0 and 'row'or 'column',m);compare()
 shader:send('value',i%7==0 and -1/math.huge or i);compare()
end
-- Long prefixes must survive many shorter writes and variant creation.
shader:send('arr',{1,2,3,4},{5,6,7,8},{9,10,11,12},{13,14,15,16})
for i=1,30 do shader:send('arr',{i,0,0,0});shader:send('value',i);compare()end
shader:send('gate',1);compare();T.eq(g.draw().arr[4][4],16)
-- Weak texture wrappers can be recycled without confusing vector storage.
local texture=newproxy(true);getmetatable(texture).__index={typeOf=function(_,k)return k=='Texture'end,getDimensions=function()return 8,8 end}
for i=1,20 do shader:send('tex',texture);shader:send('arr',{i,i+1});compare()end
-- Unknown writes still disable the adapter, even when an old destination has
-- a value in the missing input slot. Native successful calls remain observable.
for _,bad in ipairs{{[1]=1,[3]=3},{1,2,extra=3},setmetatable({1,2},{})}do
 local s=g.newShader(source);g.setShader(s);s:send('gate',0);s:send('lit',true)
 s:send('arr',{1,2,3});s:send('arr',{4,5,6});s:send('arr',bad)
 g.draw();T.eq(actual,s,'unsupported input retains original native shader')
end
-- Allocation-sensitive operation benchmark, with no graphics timing claim.
-- The fake native seam counts calls but performs no Lua value copies here.
local vectors={};for i=1,128 do vectors[i]={1,2,3,4}end
local timings={}
quiet=true
for _,reuse in ipairs{false,true,true,false}do
 S.recycleSnapshots=reuse
 local s=g.newShader(source);g.setShader(s);s:send('gate',0);s:send('lit',true);g.draw()
 for i=1,20 do s:send('arr',unpack(vectors))end
 local before=totalWrites;local started=os.clock()
 for i=1,1200 do vectors[1][1]=i;s:send('arr',unpack(vectors))end
 timings[#timings+1]=os.clock()-started
 T.eq(totalWrites-before,2400,'every original and eager variant send retained')
end
print('SNAPSHOT_REUSE_OPERATION_ABBA_SECONDS',unpack(timings))
love,jit,os.getenv,Performance.shaderBranchSpecialization=oldLove,oldJit,oldEnv,oldFlag
package.loaded['src.render.LegacyShaderCompat'],package.loaded['src.render.AlphaDepthCompat']=oldLegacy,oldAlpha
T.finish('shader snapshot reuse preserves mutable values, prefixes, layouts, textures and fallback')
