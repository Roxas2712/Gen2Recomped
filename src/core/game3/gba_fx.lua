-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native five-bit colour arithmetic over an existing draw callback. Alpha
-- reuses the native underlay snapshot and executes the callback exactly once.
local Scope=require('src.render.GraphicsScope')
local Alpha=require('src.render.NativeGbaAlpha')
local F={WHITE={31,31,31},BLACK={0,0,0}}
F.SOURCE=[[
extern Image nativeGbaUnderlay;
extern vec2 nativeGbaSurfacePixels;
extern vec2 nativeGbaCoefficients;
extern vec4 gbaFxFade;
extern vec4 gbaFxControls; // gray, brightness, alpha enabled, target density
extern vec2 gbaFxBand;
extern Image gbaFxMask;
extern vec4 gbaFxWindow;
extern vec2 gbaFxWindowControl;
vec4 effect(vec4 tint, Image texture, vec2 uv, vec2 screen) {
 vec4 pixel=Texel(texture,uv);
 if(pixel.a<0.5)discard;
 vec3 value=floor(clamp(pixel.rgb,0.0,1.0)*31.0+0.5);
 if(gbaFxControls.x>0.5){
  float gray=floor(dot(value,vec3(76.0,151.0,29.0))/256.0);
  float shade=0.0;
  if(gray>=30.0)shade=31.0;
  else if(gray>=25.0)shade=27.0;
  else if(gray>=20.0)shade=21.0;
  else if(gray>=15.0)shade=16.0;
  else if(gray>=10.0)shade=11.0;
  else if(gray>=5.0)shade=5.0;
  value=vec3(shade);
 }
 value+=floor((gbaFxFade.rgb-value)*gbaFxFade.a);
 vec2 point=screen/gbaFxControls.w;
 float brightness=gbaFxControls.y;
 if(gbaFxBand.x>0.5)brightness=max(0.0,15.0-abs(floor(point.y)-gbaFxBand.y))/16.0;
 if(gbaFxWindowControl.x>0.5){
  vec2 mask=(point-gbaFxWindow.xy)/gbaFxWindow.zw;
  if(mask.x>=0.0&&mask.y>=0.0&&mask.x<1.0&&mask.y<1.0&&Texel(gbaFxMask,mask).a>0.5)
   brightness=gbaFxWindowControl.y;
 }
 value+=floor((vec3(31.0)-value)*brightness);
 if(gbaFxControls.z>0.5){
  vec3 under=floor(clamp(Texel(nativeGbaUnderlay,screen/nativeGbaSurfacePixels).rgb,0.0,1.0)*31.0+0.5);
  value=min(vec3(31.0),floor((value*nativeGbaCoefficients.x+under*nativeGbaCoefficients.y)/16.0));
  return vec4(value/31.0,1.0);
 }
 return vec4(value/31.0,tint.a);
}
]]
local pool,depth,retiring={},0,false
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function finite(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge end
local function coefficient(value)
 value=value or 0;assert(finite(value),'invalid GBA colour coefficient')
 return math.max(0,math.min(16,math.floor(value)))
end
local function parameters(fx,blend)
 assert(fx==nil or fx==false or type(fx)=='table','GBA effects must be a table')
 assert(blend==nil or blend==false or type(blend)=='table','GBA blend must be a table')
 fx=fx or{}
 local color=fx.color or F.BLACK
 assert(type(color)=='table','GBA fade colour must have three channels')
 for i=1,3 do assert(finite(color[i])and color[i]%1==0 and color[i]>=0 and color[i]<=31,'invalid GBA fade channel')end
 assert(fx.gray==nil or type(fx.gray)=='boolean','GBA grayscale must be a boolean')
 assert(fx.band==nil or finite(fx.band),'invalid GBA brightness band')
 local win=fx.objWin
 if win then
  assert(type(win)=='table'and win.image and finite(win.x)and finite(win.y)
   and finite(win.w)and win.w>0 and finite(win.h)and win.h>0,'invalid GBA object window')
 end
 return{color=color,y=coefficient(fx.y),gray=fx.gray==true,bldy=coefficient(fx.bldy),band=fx.band,
  win=win,winBldy=win and coefficient(win.bldy)or 0,
  blend=not not blend,eva=blend and coefficient(blend.eva)or 0,evb=blend and coefficient(blend.evb)or 0}
end
function F.active(fx,blend)
 return not not(blend or fx and((fx.y or 0)>0 or fx.gray or(fx.bldy or 0)>0 or fx.objWin or fx.band~=nil))
end
local function release()
 if depth>0 then retiring=true;return end
 for _,bank in pairs(pool)do bank.alpha:release();bank.blank:release()end
 pool={};retiring=false
end
function F.draw(draw,fx,blend)
 assert(type(draw)=='function','GBA effect painter must be callable')
 local p=parameters(fx,blend)
 if not F.active(fx,blend)then return draw()end
 assert(depth<8,'GBA colour nesting limit exceeded')
 depth=depth+1
 local bank,values
 local ok,why=Scope.call(function()
  local g=love.graphics
  bank=pool[depth]
  if not bank then
   local blank=g.newCanvas(1,1,{format='rgba8',dpiscale=1,msaa=0})
   bank={alpha=Alpha.new(F.SOURCE),blank=blank};pool[depth]=bank
  end
  local function configure(shader)
   local target=g.getCanvas();if type(target)=='table'and not target.getDimensions then target=target[1];if type(target)=='table'and not target.getDimensions then target=target[1]end end
   local dpi=target and target.getDPIScale and target:getDPIScale()or g.getDPIScale and g.getDPIScale()or 1
   shader:send('gbaFxFade',{p.color[1],p.color[2],p.color[3],p.y/16})
   shader:send('gbaFxControls',{p.gray and 1 or 0,p.bldy/16,p.blend and 1 or 0,dpi})
   shader:send('gbaFxBand',{p.band~=nil and 1 or 0,p.band or 0})
   local w=p.win
   shader:send('gbaFxWindow',w and{w.x,w.y,w.w,w.h}or{0,0,1,1})
   shader:send('gbaFxWindowControl',{w and 1 or 0,p.winBldy/16})
   shader:send('gbaFxMask',w and w.image or bank.blank)
  end
  local function paint()values=pack(draw())end
  if p.blend then
   local painted,reason=bank.alpha:paint(p.eva,p.evb,paint,configure)
   if not painted then error(reason,0)end
  else
   local shader=bank.alpha:program();configure(shader)
   shader:send('nativeGbaUnderlay',bank.blank)
   g.setShader(shader);paint()
  end
 end)
 -- Never keep a borrowed object-window image alive in a cached uniform.
 local detached,detachError=true
 if bank and bank.alpha.shader then detached,detachError=pcall(bank.alpha.shader.send,bank.alpha.shader,'gbaFxMask',bank.blank)end
 depth=depth-1
 if depth==0 and retiring then release()end
 if not ok then error(why,0)end
 if not detached then error(detachError,0)end
 return unpack(values,1,values.n)
end
function F.withClip(clip,draw)
 assert(type(draw)=='function','GBA clip painter must be callable')
 if not clip then return draw()end
 for _,key in ipairs{'x','y','w','h'}do assert(finite(clip[key]),'invalid GBA clip rectangle')end
 local result=pack(Scope.call(function()
  love.graphics.intersectScissor(clip.x,clip.y,math.max(0,clip.w),math.max(0,clip.h))
  return draw()
 end))
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
F._service={release=release,releaseOwner=release}
require('src.core.game3.asset_stream').register(F._service)
return F
