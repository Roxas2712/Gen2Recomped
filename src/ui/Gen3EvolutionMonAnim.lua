-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Private reference sprites reuse the host's admitted Emerald front motions.
local M={}
function M.new(game,row,raw)
 local Motion=require('src.pokemon.MonAnim');local Pictures=require('src.pokemon.PicAnim')
 local A={};local current,tintShader
 function A.enabled()
  return require('src.core.GameVersion').get()=='emerald'and(Motion.record(game.data,raw.species)~=nil
   or Pictures.record(game.data,raw.species,raw)~=nil)
 end
 function A.newSprite(n)return{species=n,frame=0}end
 function A.run(sprite)current=sprite;return sprite end
 function A.stop(sprite)sprite.stopped=true;if current==sprite then current=nil end end
 function A.doFront(sprite,n,back,pan,opts)
  local key=row(n).id;sprite.motion=Motion.new(game.data,key);sprite.pictures=Pictures.new(game.data,key,raw)
  if sprite.motion then sprite.motion:start()end;if sprite.pictures then sprite.pictures:start()end
  if opts and opts.cry then opts.cry(n)end
 end
 function A.step()
  if not current or current.stopped then return end
  if current.motion then current.motion:update(1/60)end
  if current.pictures then current.pictures:update(1/60);current.frame=current.pictures:frame()end
 end
 function A.busy(sprite)
  return not sprite.stopped and((sprite.motion and sprite.motion:active())
   or(sprite.pictures and not sprite.pictures.paused and sprite.pictures.steps~=nil))or false
 end
 function A.framePic(n,frame)
  if not frame or frame<=0 then return end
  local rec=Pictures.record(game.data,row(n).id,raw);local img=rec and Pictures.frameImage(rec,frame,raw)
  return img and{image=img}or nil
 end
 function A.draw(sprite,img,cx,cy)
  local t=sprite.motion and sprite.motion:transform()or Motion.IDENTITY
  local previous=love.graphics.getShader()
  if t.tint then
   if not tintShader then tintShader=love.graphics.newShader([[
    extern vec4 evolutionTint;
    vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
     vec4 pixel=Texel(image,uv);
     return vec4(mix(pixel.rgb,evolutionTint.rgb,evolutionTint.a),pixel.a)*color;
    }
   ]])end
   tintShader:send('evolutionTint',t.tint);love.graphics.setShader(tintShader)
  end
  love.graphics.setColor(1,1,1,t.alpha or 1)
  love.graphics.draw(img,cx+(t.dx or 0),cy+(t.dy or 0),t.rot or 0,t.sx or 1,t.sy or 1,32,32)
  love.graphics.setShader(previous)
 end
 function A.close()if current then A.stop(current)end;if tintShader then tintShader:release();tintShader=nil end end
 return A
end
return M
