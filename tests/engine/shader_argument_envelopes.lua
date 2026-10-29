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
S.recycleSnapshots=true;S.recycleArguments=true
local shader=g.newShader(source);g.setShader(shader)
shader:send('gate',0);shader:send('lit',true);g.draw()
local function recordFor(target)
 for i=1,30 do local name,value=debug.getupvalue(methods.send,i);if not name then break end;if name=='originals'then return assert(value[target])end end
 error('native adapter record not found')
end
local record=recordFor(shader)
for i=1,100 do
 local a,b,c=shader:send('value',i)
 T.eq(a,'native-success');T.eq(b,nil);T.eq(c,17);T.eq(g.draw().value[1],i)
 T.eq(record.argumentSpare.n,0,'leased argument buffer is empty after successful native send')
 for j=1,4 do T.eq(record.argumentSpare[j],nil,'no argument reference retained')end
end
T.check(S.status().argumentEnvelopeReuses>90,'small envelope reuse actually occurred')
local vector={1,2,3,4};shader:send('arr',vector)
vector[1]=99;shader:send('gate',1);T.eq(g.draw().arr[1][1],1,'caller mutation cannot enter replay')
local matrix={};for i=1,16 do matrix[i]=i end
shader:send('matrix','column',matrix);T.eq(g.draw().matrix[2][16],16,'three-argument layout preserved')
shader:send('arr',{2,3,4,5},{6,7,8,9},{10,11,12,13})
T.eq(g.draw().arr[3][4],13,'four argument envelope retained')
shader:send('arr',{3,4,5,6},{7,8,9,10},{11,12,13,14},{15,16,17,18})
T.eq(g.draw().arr[4][4],18,'large sends retain ordinary packing')
callback=function(self,name)
 T.eq(self,shader);T.eq(name,'arr')
 shader:send('value',777)
end
shader:send('arr',{33,44,55,66})
T.eq(g.draw().arr[1][1],33,'outer lease survives nested native setter')
T.eq(g.draw().value[1],777,'nested setter state retained')
T.eq(record.argumentSpare.n,0,'nested leases return an empty bounded spare')
callback=function()error('owned setter failure')end
local ok,why=pcall(shader.send,shader,'value',999)
T.check(not ok and tostring(why):find('owned setter failure',1,true),'native errors propagate')
shader:send('value',888);T.eq(g.draw().value[1],888,'a failed lease cannot poison the next write')
local texture=newproxy(true);getmetatable(texture).__index={typeOf=function(_,kind)return kind=='Texture'end,getDimensions=function()return 8,8 end}
shader:send('tex',texture);T.eq(record.argumentSpare[2],nil,'argument spare never owns a Texture')
T.eq(g.draw().tex[1],texture,'actual replay still owns current native resource')
quiet=true;S.deduplicateUniforms=false
local timings={}
for _,enabled in ipairs{false,true,true,false}do
 S.recycleArguments=enabled
 local expected=1;for _,v in pairs(record.variants)do if v and methods.hasUniform(v.shader,'value')then expected=expected+1 end end
 local started=os.clock();local before=totalWrites
 for i=1,20000 do shader:send('value',i)end
 timings[#timings+1]=os.clock()-started
 T.eq(totalWrites-before,20000*expected,'original and every cached native variant remain eager')
end
print('SHADER_ARGUMENT_ENVELOPE_OPERATION_ABBA_SECONDS',unpack(timings))
love,jit,os.getenv,Performance.shaderBranchSpecialization=oldLove,oldJit,oldEnv,oldFlag
package.loaded['src.render.LegacyShaderCompat'],package.loaded['src.render.AlphaDepthCompat']=oldLegacy,oldAlpha
T.finish('bounded native argument envelopes preserve returns, resources, arrays, reentrancy and errors')
