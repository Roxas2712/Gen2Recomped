-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
return function(check)
  local g=love.graphics
  local I=require('src.render.PaletteIndex')
  local P=require('src.render.PaletteFX')
  local Performance=require('src.core.Performance')
  Performance.paletteIndexRendering=false
  check(P.indexShader()==nil,'index shader is opt-in')
  Performance.paletteIndexRendering=true
  local shader=assert(P.indexShader(),'index shader must compile')
  local source=love.image.newImageData(256,256)
  for a=0,255 do for r=0,255 do source:setPixel(r,a,r/255,r/255,r/255,a/255)end end
  local texture=g.newImage(I.fromImageData(source),{linear=true,mipmaps=false})
  texture:setFilter('nearest','nearest')
  local rows={}
  for p=1,16 do rows[p]={};for c=1,4 do rows[p][c]={(p*17+c*29)%256,(p*37+c*13)%256,(p*11+c*47)%256}end end
  local lut=I.lut(rows)
  check(lut.width==64 and #lut.data:getString()==256,'LUT holds exactly 16x4 RGBA colors')
  for p=1,16 do for c=1,4 do
    local r,green,b,a=lut.data:getPixel((p-1)*4+c-1,0)
    check(math.floor(r*255+.5)==rows[p][c][1] and math.floor(green*255+.5)==rows[p][c][2]
      and math.floor(b*255+.5)==rows[p][c][3] and a==1,'palette-major LUT layout')
  end end
  local revision=lut.revision
  check(lut:update(rows)==false and lut.revision==revision,'unchanged palette skips upload')
  rows[7][2][1]=(rows[7][2][1]+1)%256
  check(lut:update(rows)==true and lut.revision==revision+1,'in-place edit updates the existing LUT')
  local previous=lut.data:getString();local old=rows[3][1][1];rows[3][1][1]=0/0
  check(not pcall(lut.update,lut,rows) and lut.data:getString()==previous,'invalid update cannot partially change LUT')
  rows[3][1][1]=old
  local canvas=g.newCanvas(256,256,{dpiscale=1})
  local function frame(image,sh)
    g.push('all');g.setCanvas(canvas);g.origin();g.setShader(sh);g.setColor(1,1,1,1)
    g.setBlendMode('alpha');g.clear(.2,.3,.4,1);g.draw(image);g.setCanvas();g.pop()
    local data=canvas:newImageData();local bytes=data:getString();data:release();return bytes
  end
  local comparisons=0
  local first
  for _,slot in ipairs{0,6,15}do for _,keyed in ipairs{false,true}do
    local c=rows[slot+1]
    local reference=source:clone()
    reference:mapPixel(function(_,_,r,green,b,a)
      local index=r>.83 and 1 or r>.5 and 2 or r>.17 and 3 or 4
      local col=c[index]
      return col[1]/255,col[2]/255,col[3]/255,keyed and index==1 and 0 or a
    end)
    local image=g.newImage(reference,{linear=true,mipmaps=false});image:setFilter('nearest','nearest')
    I.bind(shader,lut,slot,keyed)
    local actual,expected=frame(texture,shader),frame(image,nil)
    if slot==0 and not keyed then first=actual end
    check(actual==expected,'index LUT matches RGBA bake for all red/alpha bytes, slot '..slot..' key '..tostring(keyed))
    image:release();reference:release();comparisons=comparisons+1
  end end
  -- Rebind after raw foreign writes, and test all generation guards.
  shader:send('paletteSlot',15);I.bind(shader,lut,0,false)
  check(frame(texture,shader)==first,'bind recovers from foreign shader uniform writes')
  local textureIdentity=lut.image
  check(lut:update(rows[1]) and lut.count==1 and lut.image==textureIdentity,'shrinking LUT keeps its GPU image')
  local r,green,b=lut.data:getPixel(63,0)
  check(r==0 and green==0 and b==0,'shrinking LUT clears retired palette slots')
  check(not pcall(I.bind,shader,lut,1,false),'retired palette slots cannot be drawn')
  local V=require('src.core.GameVersion');local oldVersion=V.get()
  V.set('firered');check(P.indexShader()==nil,'Gen 3 never selects Gen 1/2 shader');V.set(oldVersion)
  Performance.paletteIndexRendering=false
  lut:release();lut:release();canvas:release();texture:release();source:release()
  return {comparisons=comparisons,maxByteDelta=0,lutBytes=256}
end
