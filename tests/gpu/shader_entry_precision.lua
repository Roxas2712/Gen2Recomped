-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual LÖVE12 constructor/validator and asymmetric texture readback.
local M={}
function M.run()
 assert(love.getVersion()>=12,'This GPU contract requires the actual LOVE12 runtime')
 local rawCompiler=love.graphics.newShader
 require('src.render.LegacyShaderCompat').install()
 local g=love.graphics
 local canvas=g.newCanvas(8,8,{dpiscale=1,format='rgba8',readable=true})
 local data=love.image.newImageData(8,8)
 for y=0,7 do for x=0,7 do data:setPixel(x,y,y<4 and 1 or 0,0,y<4 and 0 or 1,1)end end
 local image=g.newImage(data);image:setFilter('nearest','nearest')
 local report={passed=false,checks=0,cases={},scope='Real LOVE12 synthetic shader entry compilation, validation and exact asymmetric GPU pixels; no third-party mod/gameplay acceptance.'}
 local vertex='vec4 position(mat4 m,vec4 v){return m*v;}'
 for _,q in ipairs{'lowp','mediump','highp'}do
  local source=vertex..'\n#ifdef PIXEL\n'..q..' vec4 effect('..q..' vec4 color, Image tex, '..q..' vec2 uv, '..q..' vec2 screen){if(uv.x<0.25)discard;return Texel(tex,uv)*color;}\n#endif'
  local rawOK,raw=pcall(rawCompiler,source)
  if rawOK then raw:release()end
  local valid,message=g.validateShader(false,source)
  assert(valid,'Adapted validation failed: '..tostring(message))
  local shader=g.newShader(source)
  g.push('all');g.origin();g.setCanvas(canvas);g.setScissor();g.setDepthMode();g.setShader(shader);g.setColor(1,1,1,1)
  g.setBlendMode('replace','premultiplied');g.clear(0,0,0,0);g.draw(image,0,0);g.pop()
  local pixels=g.readbackTexture(canvas)
  for y=0,7 do for x=0,7 do
   local r,green,b,a=pixels:getPixel(x,y)
   if x<2 then assert(a<1/255,'authored discard lost')
   elseif y<4 then assert(r>.99 and green<.01 and b<.01 and a>.99,'upper red texel changed or flipped')
   else assert(r<.01 and green<.01 and b>.99 and a>.99,'lower blue texel changed or flipped')end
   report.checks=report.checks+1
  end end
  pixels:release();shader:release()
  report.cases[#report.cases+1]={precision=q,rawCompiled=rawOK,rawError=not rawOK and tostring(raw)or nil,adaptedValidation=true,adaptedPixels=true}
 end
 image:release();data:release();report.passed=true
 return report,canvas
end
return M
