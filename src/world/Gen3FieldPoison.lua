-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Field poison writes BG MOSAIC; neither OBJ nor BG0's popup/text is enabled.
local M={}
local supported={ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
function M.start(state,version)
 if not supported[version]then return false end
 state.gen3PoisonMosaic={frame=1,step=(version=='firered'or version=='leafgreen')and 1 or 2}
 return true
end
function M.tick(state)
 local effect=state.gen3PoisonMosaic
 if not effect then return end
 effect.frame=effect.frame+1
 if effect.frame>10 then state.gen3PoisonMosaic=nil end
end
function M.size(state)
 local effect=state.gen3PoisonMosaic
 if not effect then return 1 end
 local f=effect.frame
 return 1+(f<=5 and f or 10-f)*effect.step
end
local shader
local code=[[
extern vec2 sourceSize;
extern float mosaicSize;
vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
 vec2 pixel=floor(uv*sourceSize);
 vec2 samplePixel=floor(pixel/mosaicSize)*mosaicSize+vec2(0.5);
 return Texel(image,min(samplePixel,sourceSize-vec2(0.5))/sourceSize)*color;
}
]]
-- Capture a complete background pass at world-pixel resolution. Quantizing a
-- tile atlas would restart the mosaic grid at every quad. UI/actors never enter
-- this surface, and the final renderer still owns window scaling and fades.
function M.background(state,w,h,draw,...)
 local size=M.size(state)
 if size<=1 then return draw(...)end
 local g=love.graphics
 local canvas=state.gen3PoisonCanvas
 if not canvas or canvas:getWidth()~=w or canvas:getHeight()~=h then
  if canvas and canvas.release then canvas:release()end
  canvas=require('src.render.PixelCanvas').new(w,h,'nearest');state.gen3PoisonCanvas=canvas
 end
 shader=shader or g.newShader(code)
 local target=g.getCanvas();g.push('all');g.setCanvas(canvas);g.clear(0,0,0,0)
 local ok,why=pcall(draw,...)
 if ok then
  g.setCanvas(target);g.origin();g.setScissor();g.setShader(shader)
  shader:send('sourceSize',{w,h});shader:send('mosaicSize',size)
  g.setColor(1,1,1,1);g.setBlendMode('alpha','premultiplied');g.draw(canvas,0,0)
 end
 g.setCanvas(target);g.pop()
 if not ok then error(why,0)end
end
return M
