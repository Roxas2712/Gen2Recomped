-- The companion wordmark is revealed line by line, like ink travelling
-- across the letters. This affects the intro only; game rendering stays crisp.
local J={}
local Score=require('src.import.LauncherIntroScore')
local function clamp(n) return math.max(0,math.min(1,n)) end
function J.progress(t)
  return clamp((t-Score.journeyStart)/(Score.journeyLine2-Score.journeyStart)),
    clamp((t-Score.journeyLine2)/(Score.journeyComplete-Score.journeyLine2)),
    1-clamp((t-(Score.journeyComplete+.72))/(Score.journeyFade-Score.journeyComplete-.72))
end
function J.draw(self,t,x,y,w,h)
  local first,second,alpha=J.progress(t)
  if alpha<=0 or first<=0 then return end
  local g=love.graphics
  if self._journeyImage==nil then
    local ok,image=pcall(g.newImage,'assets/launcher/journey_wordmark.png')
    self._journeyImage=ok and image or false
    if image and ok then image:setFilter('linear','linear') end
  end
  if not self._journeyImage then return end
  if self._journeyShader==nil then
    local ok,shader=pcall(g.newShader,[[
      extern number first; extern number second;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
        vec4 pixel=Texel(tex,uv)*color;
        number progress=mix(first,second,smoothstep(.49,.57,uv.y));
        pixel.a*=1.0-smoothstep(progress-.008,progress+.008,uv.x);
        pixel.rgb+=vec3(.15,.22,.24)*exp(-abs(uv.x-progress)*200.0);
        return pixel;
      }
    ]])
    self._journeyShader=ok and shader or false
  end
  local iw,ih=self._journeyImage:getDimensions()
  local scale=math.min(w*.82/iw,h*.265/ih)
  g.push('all');g.setColor(1,1,1,alpha)
  if self._journeyShader then
    self._journeyShader:send('first',first>=1 and 1.02 or first)
    self._journeyShader:send('second',second>=1 and 1.02 or second)
    g.setShader(self._journeyShader)
  else
    g.setScissor(x+(w-iw*scale)/2,y+h*.035,iw*scale*math.max(first,second),ih*scale)
  end
  g.draw(self._journeyImage,x+(w-iw*scale)/2,y+h*.035,0,scale,scale)
  g.pop()
end
return J
