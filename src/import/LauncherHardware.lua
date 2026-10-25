-- Lightweight 2.5D hardware: bevelled faces, side walls, contact pins and
-- recognizable handheld silhouettes. No external models or ROM art needed.
local Hardware = {}
local Versions = require('src.core.GameVersion')
local function color(rgb,a) love.graphics.setColor(rgb[1]/255,rgb[2]/255,rgb[3]/255,a or 1) end
local function shade(rgb,k) return {rgb[1]*k,rgb[2]*k,rgb[3]*k} end

function Hardware.kind(version)
  local info=Versions.info(version)
  local gen=info and info.generation or 1
  return gen>=4 and 'nds' or gen==3 and 'gba' or gen==2 and 'gbc' or 'gb'
end

function Hardware.cartSize(version)
  local kind=Hardware.kind(version)
  if kind=='gba' then return 156,92 end
  if kind=='nds' then return 108,120 end
  return 132,164
end

function Hardware.cartridge(self,version,cx,cy,maxW,maxH,angle)
  local g=love.graphics
  local Library=require('src.import.LauncherLibrary')
  local accent,name=Library.edition(version)
  local design=self._cartStyle and self:_cartStyle(version) or {}
  local shell=design.shell or accent
  local label=design.label or shade(accent,0.32)
  name=design.name and design.name~='' and design.name or name
  local w,h=Hardware.cartSize(version)
  local sc=math.min(maxW/(w+12),maxH/(h+12))
  g.push('all');g.translate(cx,cy);g.rotate(angle or -0.055);g.scale(sc)
  g.translate(-w/2,-h/2)
  -- The top and right side are actual separate faces, visible at rest too.
  color({0,0,0},0.28);g.rectangle('fill',9,14,w,h,9,9)
  color(shade(shell,0.36));g.polygon('fill',w-2,4,w+10,13,w+10,h+4,w-2,h-2)
  color(shade(shell,1.1));g.polygon('fill',8,-5,w-4,-5,w+10,7,0,7)
  color(shade(shell,0.72));g.rectangle('fill',0,0,w,h,8,8)
  color(shell,0.68);g.rectangle('fill',3,2,w-7,h-5,7,7)
  color({255,255,255},0.3);g.line(8,3,w-10,3)
  color({0,0,0},0.25);g.line(w-3,10,w-3,h-10)
  local kind=Hardware.kind(version)
  local labelY=kind=='gba' and 19 or 29
  local labelH=h-labelY-21
  color(shade(shell,0.26));g.rectangle('fill',11,labelY,w-22,labelH,5,5)
  color(label);g.rectangle('fill',15,labelY+4,w-30,labelH-8,3,3)
  for i=0,2 do color({255,255,255},0.16);g.line(17,9+i*4,w-18,9+i*4) end
  local image=design.image
  if image then
    local iw,ih=image:getDimensions()
    local fit=math.min((w-38)/iw,(labelH-20)/ih)
    g.setColor(1,1,1,1);g.draw(image,(w-iw*fit)/2,labelY+8+(labelH-20-ih*fit)/2,0,fit,fit)
  else
    local mx,my=w/2,labelY+labelH*0.43
    color(shell,0.9);g.setLineWidth(2)
    if design.pattern=='pixels' then
      for yy=-2,2 do for xx=-2,2 do
        if (xx*xx+yy*yy)%3~=0 then g.rectangle('fill',mx+xx*6-2,my+yy*6-2,4,4) end
      end end
    elseif design.pattern=='bolt' then
      g.polygon('fill',mx+4,my-20,mx-14,my+3,mx-2,my+3,mx-6,my+21,mx+15,my-5,mx+3,my-5)
    else
      local radius=math.min(22,labelH*0.25)
      g.circle('line',mx,my,radius);g.line(mx-radius,my,mx+radius,my)
      color(label);g.circle('fill',mx,my,radius*0.3)
      color(shell);g.circle('line',mx,my,radius*0.3)
    end
  end
  local font=self.labelFont or g.getFont()
  g.setFont(font)
  local fs=math.min(1/(self._s or 1),(w-40)/math.max(1,font:getWidth(name)))
  color({247,247,239});g.print(name,w/2-font:getWidth(name)*fs/2,labelY+labelH-20,0,fs,fs)
  -- Gold edge connector catches the light as the cartridge turns.
  color({55,44,22});g.rectangle('fill',w*0.27,h-13,w*0.46,13,2,2)
  for i=0,7 do color({218,185,104});g.rectangle('fill',w*0.29+i*w*0.052,h-11,w*0.032,10) end
  color({255,255,255},0.16);g.polygon('fill',6,4,w*0.45,4,6,h*0.65)
  g.pop()
end

function Hardware.deviceGeometry(version,cx,cy,s)
  local kind=Hardware.kind(version)
  local w,h,top
  if kind=='gba' then w,h,top=330*s,165*s,cy+20*s
  elseif kind=='nds' then w,h,top=220*s,275*s,cy-100*s
  else w,h,top=170*s,264*s,cy-60*s end
  return {kind=kind,x=cx-w/2,y=top,w=w,h=h,slotX=cx,slotY=top}
end

function Hardware.screenPoint(geometry)
  local kind=geometry.kind
  local base=kind=='gba' and 330 or kind=='nds' and 220 or 170
  local s=geometry.w/base
  local px=kind=='gba' and 165 or kind=='nds' and 110 or 87
  local py=kind=='gba' and 76 or kind=='nds' and 65 or 76.5
  return geometry.x+px*s,geometry.y+py*s,(kind=='gba' and 170 or kind=='nds' and 156 or 108)*s
end

local function dpad(x,y,r)
  local g=love.graphics
  color({19,22,30});g.rectangle('fill',x-r,y-r*0.34,r*2,r*0.68,2,2)
  g.rectangle('fill',x-r*0.34,y-r,r*0.68,r*2,2,2)
  color({255,255,255},0.12);g.line(x-r+2,y-r*0.34+1,x-r*0.34,y-r*0.34+1)
end
local function screen(self,x,y,w,h,on,accent)
  local g=love.graphics
  color({13,18,26});g.rectangle('fill',x,y,w,h,5,5)
  color(accent,on and 0.15 or 0.035);g.rectangle('fill',x+3,y+3,w-6,h-6,3,3)
  color({255,255,255},0.045);g.polygon('fill',x+4,y+4,x+w*0.7,y+4,x+4,y+h*0.8)
  if on then
    local logo=self.gen2Logo or self.logo
    if logo then
      local lw,lh=logo:getDimensions();local sc=math.min(w*0.85/lw,h*0.55/lh)
      g.setColor(1,1,1,0.95);g.draw(logo,x+(w-lw*sc)/2,y+(h-lh*sc)/2,0,sc,sc)
    end
  end
end

function Hardware.device(self,version,geometry,connected)
  local g=love.graphics
  local accent=require('src.import.LauncherLibrary').edition(version)
  local x,y,w,h=geometry.x,geometry.y,geometry.w,geometry.h
  local kind=geometry.kind
  local baseW=kind=='gba' and 330 or kind=='nds' and 220 or 170
  local s=w/baseW
  g.push('all');g.translate(x,y);g.scale(s)
  local bw,bh=w/s,h/s
  local shell=kind=='gb' and {188,187,174} or kind=='gbc' and {87,72,132} or kind=='gba' and {86,76,139} or {73,81,99}
  color({0,0,0},0.32);g.rectangle('fill',8,16,bw,bh,18,18)
  color(shade(shell,0.4));g.rectangle('fill',5,9,bw,bh,18,18)
  color(shell);g.rectangle('fill',0,0,bw,bh,18,18)
  color({255,255,255},0.22);g.rectangle('line',1,1,bw-2,bh-2,18,18)
  color({8,10,17});g.rectangle('fill',bw*0.27,-3,bw*0.46,7,3,3)
  if kind=='gba' then
    color({27,29,43});g.rectangle('fill',67,16,196,125,12,12)
    screen(self,80,28,170,96,connected,accent)
    dpad(34,78,17)
    color({166,166,185});g.circle('fill',291,62,12);g.circle('fill',272,91,12)
    color({30,34,48});g.ellipse('fill',44,124,8,4);g.ellipse('fill',61,128,8,4)
  elseif kind=='nds' then
    color({21,27,38});g.rectangle('fill',20,14,180,106,9,9)
    screen(self,32,24,156,82,connected,accent)
    color(shade(shell,0.6));g.rectangle('fill',0,129,220,12,5,5)
    color({21,27,38});g.rectangle('fill',49,151,122,102,8,8)
    screen(self,56,158,108,88,connected,accent)
    dpad(25,194,14)
    color({27,31,43});for _,p in ipairs({{192,177},{207,192},{177,192},{192,207}}) do g.circle('fill',p[1],p[2],6) end
  else
    color(kind=='gb' and {73,75,82} or {30,34,53});g.rectangle('fill',14,20,142,116,10,10)
    screen(self,33,35,108,83,connected,kind=='gb' and {158,174,111} or accent)
    dpad(42,186,19)
    color(kind=='gb' and {139,44,75} or {37,36,49});g.circle('fill',132,172,12);g.circle('fill',110,193,12)
    color({45,46,55});g.rectangle('fill',61,228,19,6,3,3);g.rectangle('fill',87,228,19,6,3,3)
    for i=0,4 do color(shade(shell,0.57));g.line(116+i*7,234,121+i*7,247) end
    color(connected and {143,240,168} or {68,76,76});g.circle('fill',24,48,2.5)
  end
  g.pop()
end

-- The same device family, reduced to a recognizable library-card symbol.
function Hardware.symbol(self,kind,cx,cy,height)
  local version=({gb='red',gbc='crystal',gba='emerald',nds='heartgold'})[kind]
  if not version then return end
  local ratio=kind=='gba' and 2 or kind=='nds' and 220/275 or 170/264
  local w=height*ratio
  Hardware.device(self,version,{kind=kind,x=cx-w/2,y=cy-height/2,w=w,h=height},false)
end

return Hardware
