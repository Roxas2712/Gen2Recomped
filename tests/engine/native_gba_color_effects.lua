-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fx=require('src.core.game3.gba_fx')
local Alpha=require('src.render.NativeGbaAlpha')
local g=love.graphics;local saved={}
for _,key in ipairs{'newShader','newCanvas','getScissor','setScissor','intersectScissor','clear'}do saved[key]=g[key]end
local shaders,canvases={},{}
g.newShader=function(source)
 local sh={source=source,uniforms={}}
 function sh:send(key,value)
  assert(not self.released,'released shader')
  if type(value)=='table'and not value.getDimensions then local c={};for k,v in pairs(value)do c[k]=v end;value=c end
  self.uniforms[key]=value
 end
 function sh:release()T.eq(self.released,nil,'owned shader released once');self.released=true end
 shaders[#shaders+1]=sh;return sh
end
g.newCanvas=function(w,h,options)
 local c={width=w,height=h,dpi=options and options.dpiscale or 1}
 function c:getDimensions()return self.width,self.height end
 function c:getDPIScale()return self.dpi end
 function c:setFilter()end
 function c:release()T.eq(self.released,nil,'owned canvas released once');self.released=true end
 canvases[#canvases+1]=c;return c
end
local scissor={1,2,30,40}
g.getScissor=function()return unpack(scissor)end
g.setScissor=function(...)scissor={...}end
g.intersectScissor=function(x,y,w,h)
 local sx,sy,sw,sh=unpack(scissor)
 if sx then local right,bottom=math.min(sx+sw,x+w),math.min(sy+sh,y+h);x,y=math.max(sx,x),math.max(sy,y);w,h=math.max(0,right-x),math.max(0,bottom-y)end
 scissor={x,y,w,h}
end
g.clear=function()end
local target=g.newCanvas(32,24,{dpiscale=2});local mask=g.newCanvas(8,8,{dpiscale=1})
local beforeShader={};g.setShader(beforeShader);g.setCanvas(target);g.setColor(.2,.3,.4,.5)
local function restored()
 T.eq(g.getCanvas(),target);T.eq(g.getShader(),beforeShader)
 T.same(scissor,{1,2,30,40});local r,gg,b,a=g.getColor();T.same({r,gg,b,a},{.2,.3,.4,.5})
end
T.eq(Fx.active(),false);T.eq(Fx.active({y=0}),false);T.eq(Fx.active({band=0}),true)
local created=#shaders
local a,b,c=Fx.draw(function()return 7,nil,9 end)
T.eq(a,7);T.eq(b,nil);T.eq(c,9);T.eq(#shaders,created,'inactive effects allocate no shader')
local calls=0;local outer
Fx.draw(function()
 calls=calls+1;outer=g.getShader();T.neq(outer,beforeShader)
 T.same(outer.uniforms.gbaFxFade,{31,0,12,.5})
 T.same(outer.uniforms.gbaFxControls,{1,.25,0,2})
 local fade=outer.uniforms.gbaFxFade
 Fx.draw(function()calls=calls+1;T.neq(g.getShader(),outer)end,{y=16,color=Fx.WHITE})
 T.eq(g.getShader(),outer);T.same(outer.uniforms.gbaFxFade,fade,'nested effects cannot change their caller uniforms')
end,{y=8,color={31,0,12},gray=true,bldy=4})
T.eq(calls,2);restored()
local alphaShader
a,b,c=Fx.draw(function()
 calls=calls+1;alphaShader=g.getShader()
 T.same(alphaShader.uniforms.nativeGbaCoefficients,{9,7})
 T.same(alphaShader.uniforms.nativeGbaSurfacePixels,{64,48})
 T.eq(alphaShader.uniforms.gbaFxMask,mask)
 T.same(alphaShader.uniforms.gbaFxWindow,{2,3,8,9})
 T.same(alphaShader.uniforms.gbaFxWindowControl,{1,.75})
 return 'native',nil,23
end,{objWin={image=mask,x=2,y=3,w=8,h=9,bldy=12},band=0},{eva=9,evb=7})
T.eq(a,'native');T.eq(b,nil);T.eq(c,23);T.eq(calls,3,'alpha executes the native painter once')
T.neq(alphaShader.uniforms.gbaFxMask,mask,'borrowed mask detached after painting');T.eq(mask.released,nil);restored()
local warmed=#shaders
Fx.draw(function()calls=calls+1 end,{y=2})
T.eq(#shaders,warmed,'normal repeated calls reuse a compiled depth bank');restored()
local beforeCalls=calls
for _,fx in ipairs{{y=0/0},{y='bad'},{color={32,0,0}},{gray=1},{band=math.huge},
 {objWin={image=mask,x=0,y=0,w=0,h=8}}}do
 T.raises(function()Fx.draw(function()calls=calls+1 end,fx)end,'GBA')
end
T.raises(function()Fx.draw(function()calls=calls+1 end,{y=2},{eva=math.huge})end,'coefficient')
T.eq(calls,beforeCalls,'invalid parameters cannot partially paint');restored()
T.raises(function()Fx.draw(function()
 g.push('all');g.setCanvas(mask);g.setColor(1,1,1,1);error('intentional colour painter error')
end,{objWin={image=mask,x=0,y=0,w=8,h=8}})end,'intentional colour painter error')
restored();T.eq(mask.released,nil)
local clip=Fx.withClip({x=4,y=5,w=8,h=9},function()T.same(scissor,{4,5,8,9});return 'clip'end)
T.eq(clip,'clip');restored()
T.raises(function()Fx.withClip({x=4,y=5,w=8,h=9},function()error('clip failure')end)end,'clip failure');restored()
-- Existing native-alpha users keep the same default program and owned target.
local native=Alpha.new();local configured=false
local painted=native:paint(16,0,function()calls=calls+1 end,function(shader)
 configured=true;T.eq(shader.source,Alpha.SOURCE)
end)
T.eq(painted,true);T.eq(configured,true);native:release();restored()
-- A teardown during a nested painter retires owned resources after the last
-- draw exits; it must not invalidate the currently executing program.
local active
Fx.draw(function()
 active=g.getShader();Fx._service.release()
 T.eq(active.released,nil);T.eq(mask.released,nil)
end,{y=3})
T.eq(active.released,true);restored()
Fx.draw(function()T.neq(g.getShader(),active)end,{y=1});Fx._service.release()
T.eq(mask.released,nil);T.eq(target.released,nil)
for key,value in pairs(saved)do g[key]=value end
g.setCanvas();g.setShader()
T.finish('native GBA colour effects, once-only alpha, nested ownership and release')
