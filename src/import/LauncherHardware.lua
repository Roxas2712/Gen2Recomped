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

function Hardware.cartModel(version)
  local kind=Hardware.kind(version)
  if kind=='gba' then return {w=156,h=90,depth=6,labelY=25,family='agb',
    face={4,0,152,0,156,4,156,17,150,17,150,84,144,90,12,90,6,84,6,17,0,17,0,4}} end
  if kind=='nds' then return {w=108,h=102,depth=3,labelY=12,family='ntr',
    face={4,0,91,0,108,17,108,54,103,54,103,64,108,64,108,98,104,102,4,102,0,98,0,4}} end
  -- Gold/Silver use the original notched dual-compatible GB mould, while
  -- Crystal uses the rounded Color-only shell with a visible circuit board.
  if kind=='gbc' and version~='gold' and version~='silver' then return {w=132,h=152,depth=6,labelY=37,family='cgb',
    face={0,14,5,6,18,2,38,0,94,0,114,2,127,6,132,14,132,146,126,152,6,152,0,146}} end
  return {w=132,h=152,depth=7,labelY=38,family='dmg',
    face={5,0,110,0,110,12,132,12,132,146,126,152,6,152,0,146,0,5}}
end

function Hardware.cartSize(version)
  local model=Hardware.cartModel(version)
  return model.w,model.h
end

-- Pixel-space crop shared by labels and complete, player-supplied cart photos.
function Hardware.artCrop(iw,ih,w,h,design)
  local sc=(design.artFit=='cover' and math.max(w/iw,h/ih) or math.min(w/iw,h/ih))*(design.artZoom or 1)
  local cw,ch=math.min(iw,w/sc),math.min(ih,h/sc)
  return (iw-cw)*(design.artX or .5),(ih-ch)*(design.artY or .5),cw,ch,sc
end
local function artwork(image,x,y,w,h,design)
  local g=love.graphics
  local iw,ih=image:getDimensions()
  local sx,sy,cw,ch,sc=Hardware.artCrop(iw,ih,w,h,design)
  local quad=g.newQuad(sx,sy,cw,ch,iw,ih)
  g.setColor(1,1,1,1);g.draw(image,quad,x+(w-cw*sc)/2,y+(h-ch*sc)/2,0,sc,sc)
end
function Hardware.appearance(self,version)
  local source=self._cartStyle and self:_cartStyle(version) or {}
  local design={}
  for k,v in pairs(source) do
    if type(v)=='table' then local t={};for a,b in pairs(v) do t[a]=b end;design[k]=t else design[k]=v end
  end
  return {design=design,branded=self._settings and self:_settings().launcherLogoCards,logo=self.gen2Logo or self.logo}
end

local function drawCartridge(self,version,cx,cy,maxW,maxH,angle,options)
  local g=love.graphics
  local Library=require('src.import.LauncherLibrary')
  local accent,name=Library.edition(version)
  local appearance=options and options.appearance or Hardware.appearance(self,version)
  local design=appearance.design
  local shell=design.shell or accent
  local label=design.label or shade(accent,0.32)
  name=design.name and design.name~='' and design.name or name
  local model=Hardware.cartModel(version)
  local w,h=model.w,model.h
  local sc=math.min(maxW/(w+12),maxH/(h+12))
  g.push('all');g.translate(cx,cy);g.rotate(angle or -0.055);g.scale(sc)
  g.translate(-w/2,-h/2)
  if design.image and design.artMode=='cartridge' then
    artwork(design.image,0,0,w,h,design);g.pop();return
  end
  -- The top and right side are actual separate faces, visible at rest too.
  color({0,0,0},0.26);g.push();g.translate(model.depth,model.depth+5);g.polygon('fill',model.face);g.pop()
  color(shade(shell,0.48));g.push();g.translate(model.depth,model.depth*.5);g.polygon('fill',model.face);g.pop()
  color(shade(shell,0.77));g.polygon('fill',model.face)
  color(shell);g.push();g.translate(1.5,1.5);g.scale((w-3)/w,(h-3)/h);g.polygon('fill',model.face);g.pop()
  color({255,255,255},0.22);g.setLineWidth(.65);g.polygon('line',model.face)
  color({0,0,0},0.13);g.line(w-2,27,w-2,h-10)
  local kind=Hardware.kind(version)
  local labelY=model.labelY
  local labelH=h-labelY-(kind=='nds' and 16 or kind=='gba' and 13 or 18)
  if model.family=='cgb' then
    color({38,83,70},.4);g.rectangle('fill',12,20,w-24,h-30,6,6)
    color({18,36,39},.4);g.rectangle('fill',w*.48,24,38,18,2,2)
    color({170,213,163},.4);for i=1,5 do g.line(16+i*5,25,16+i*5,h-12) end
  end
  color(shade(shell,0.26));g.rectangle('fill',11,labelY,w-22,labelH,5,5)
  color(label);g.rectangle('fill',15,labelY+4,w-30,labelH-8,3,3)
  if model.family=='dmg' then
    for i=0,(kind=='gba' and 1 or 2) do
      color({0,0,0},0.16);g.line(18,12+i*4,w-24,12+i*4)
      color({255,255,255},0.2);g.line(18,13+i*4,w-24,13+i*4)
    end
    color(shade(shell,.64));g.setLineWidth(.8);g.rectangle('line',12,6,w-36,24,7,7)
  elseif model.family=='cgb' then
    color(shade(shell,.65));g.arc('line','open',w/2,35,w*.42,math.pi*1.1,math.pi*1.9)
  elseif model.family=='agb' then
    color(shade(shell,.4));g.line(13,18,w-13,18)
    color({255,255,255},.25);g.line(14,5,w-14,5)
    for _,side in ipairs({10,w-10}) do for i=0,4 do color(shade(shell,.55));g.line(side,30+i*8,side,34+i*8) end end
  else
    color(shade(shell,.5));g.line(7,8,85,8)
  end
  local branded=appearance.branded and not (options and options.customLabel)
  local image=design.image or (branded and appearance.logo)
  if image then
    if image.setFilter then image:setFilter('linear','linear') end
    artwork(image,19,labelY+8,w-38,labelH-29,design.image and design or {})
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
  -- Contacts sit on the lower/back edge; the front is a solid moulded shell.
  color(shade(shell,.3));g.rectangle('fill',w*.22,h-2,w*.56,2,1,1)
  if kind~='nds' then
    color({0,0,0},0.2);g.polygon('fill',w*.46,h-10,w*.54,h-10,w*.5,h-5)
  end
  color({255,255,255},0.055);g.polygon('fill',6,18,w*0.4,12,6,h*0.62)
  g.pop()
end

function Hardware.cartridge(self,version,cx,cy,maxW,maxH,angle,options)
  local g=love.graphics
  if not (g.newCanvas and g.setCanvas and g.getCanvas and g.origin and g.setBlendMode) then
    return drawCartridge(self,version,cx,cy,maxW,maxH,angle,options)
  end
  -- Rasterize these vector illustrations at 3x once, then filter them down.
  -- Local supersampling smooths rotated edges without changing game pixels
  -- or requiring multisampling on the entire window every frame.
  local appearance=options and options.appearance or Hardware.appearance(self,version)
  local style=appearance.design
  local shell,label=style.shell or {},style.label or {}
  local branded=appearance.branded and not (options and options.customLabel)
  local key=table.concat({version,tostring(self.labelFont),tostring(self._s),tostring(branded),
    style.name or '',style.pattern or '',tostring(style.image),tostring(appearance.logo),
    style.artMode or '',style.artFit or '',tostring(style.artZoom),tostring(style.artX),tostring(style.artY),
    table.concat(shell,','),table.concat(label,',')},'|')
  self._hardwareCarts=self._hardwareCarts or {}
  self._hardwareCartOrder=self._hardwareCartOrder or {}
  local canvas=self._hardwareCarts[key]
  local w,h=Hardware.cartSize(version)
  local factor=3
  local originX,originY=(w/2+16)*factor,(h/2+12)*factor
  if not canvas then
    local ok,result=pcall(g.newCanvas,(w+40)*factor,(h+40)*factor,{dpiscale=1})
    if not ok or not result then return drawCartridge(self,version,cx,cy,maxW,maxH,angle,options) end
    canvas=result;canvas:setFilter('linear','linear')
    local previous=g.getCanvas()
    g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.setShader()
    g.clear(0,0,0,0);g.setBlendMode('alpha','alphamultiply')
    if g.setLineStyle then g.setLineStyle('smooth') end
    drawCartridge(self,version,originX,originY,(w+12)*factor,(h+12)*factor,0,options)
    g.setCanvas(previous);g.pop()
    self._hardwareCarts[key]=canvas
    local order=self._hardwareCartOrder;order[#order+1]=key
    if #order>24 then
      local old=table.remove(order,1)
      local retired=self._hardwareCarts[old]
      self._hardwareCarts[old]=nil
      if retired and retired.release then retired:release() end
    end
  end
  local sc=math.min(maxW/(w+12),maxH/(h+12))/factor
  g.push('all');g.setColor(1,1,1,1);g.setBlendMode('alpha','premultiplied')
  g.draw(canvas,cx,cy,angle or -0.055,sc,sc,originX,originY)
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
  local x,y,w,h=Hardware.screenRect(geometry)
  return x+w/2,y+h/2,w,h
end

function Hardware.screenRect(geometry)
  local kind=geometry.kind
  local base=kind=='gba' and 330 or kind=='nds' and 220 or 170
  local s=geometry.w/base
  local px=kind=='gba' and 80 or kind=='nds' and 32 or 33
  local py=kind=='gba' and 28 or kind=='nds' and 24 or 35
  return geometry.x+px*s,geometry.y+py*s,(kind=='gba' and 170 or kind=='nds' and 156 or 108)*s,
    (kind=='gba' and 96 or kind=='nds' and 82 or 83)*s
end

function Hardware.nativeResolution(version)
  local kind=Hardware.kind(version)
  if kind=='gba' then return 240,160,1 end
  if kind=='nds' then return 256,192,2 end
  return 160,144,1
end

local function dpad(x,y,r)
  local g=love.graphics
  color({19,22,30});g.rectangle('fill',x-r,y-r*0.34,r*2,r*0.68,2,2)
  g.rectangle('fill',x-r*0.34,y-r,r*0.68,r*2,2,2)
  color({255,255,255},0.12);g.line(x-r+2,y-r*0.34+1,x-r*0.34,y-r*0.34+1)
end
local function screen(self,x,y,w,h,on,accent,showLogo)
  local g=love.graphics
  color({13,18,26});g.rectangle('fill',x,y,w,h,5,5)
  color(accent,on and 0.15 or 0.035);g.rectangle('fill',x+3,y+3,w-6,h-6,3,3)
  color({255,255,255},0.045);g.polygon('fill',x+4,y+4,x+w*0.7,y+4,x+4,y+h*0.8)
  if on and showLogo then
    local logo=self.gen2Logo or self.logo
    if logo then
      local lw,lh=logo:getDimensions();local sc=math.min(w*0.85/lw,h*0.55/lh)
      g.setColor(1,1,1,0.95);require('src.import.LauncherTheme').drawLogo(logo,x+(w-lw*sc)/2,y+(h-lh*sc)/2,0,sc,sc)
    end
  end
end

function Hardware.device(self,version,geometry,connected,effects)
  local g=love.graphics
  local accent=require('src.import.LauncherLibrary').edition(version)
  local x,y,w,h=geometry.x,geometry.y,geometry.w,geometry.h
  local kind=geometry.kind
  local baseW=kind=='gba' and 330 or kind=='nds' and 220 or 170
  local s=w/baseW
  local powered=effects and effects.powered or (not effects and connected)
  local showLogo=not effects or effects.logo==true
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
    screen(self,80,28,170,96,powered,accent,showLogo)
    dpad(34,78,17)
    color({166,166,185});g.circle('fill',291,62,12);g.circle('fill',272,91,12)
    color({30,34,48});g.ellipse('fill',44,124,8,4);g.ellipse('fill',61,128,8,4)
  elseif kind=='nds' then
    color({21,27,38});g.rectangle('fill',20,14,180,106,9,9)
    screen(self,32,24,156,82,powered,accent,showLogo)
    color(shade(shell,0.6));g.rectangle('fill',0,129,220,12,5,5)
    color({21,27,38});g.rectangle('fill',49,151,122,102,8,8)
    screen(self,56,158,108,88,powered,accent,showLogo)
    dpad(25,194,14)
    color({27,31,43});for _,p in ipairs({{192,177},{207,192},{177,192},{192,207}}) do g.circle('fill',p[1],p[2],6) end
  else
    color(kind=='gb' and {73,75,82} or {30,34,53});g.rectangle('fill',14,20,142,116,10,10)
    screen(self,33,35,108,83,powered,kind=='gb' and {158,174,111} or accent,showLogo)
    dpad(42,186,19)
    color(kind=='gb' and {139,44,75} or {37,36,49});g.circle('fill',132,172,12);g.circle('fill',110,193,12)
    color({45,46,55});g.rectangle('fill',61,228,19,6,3,3);g.rectangle('fill',87,228,19,6,3,3)
    for i=0,4 do color(shade(shell,0.57));g.line(116+i*7,234,121+i*7,247) end
  end
  local ledX,ledY=kind=='gba' and 275 or kind=='nds' and 207 or 24,
    kind=='gba' and 31 or kind=='nds' and 132 or 48
  local ledColor=kind=='gb' and {255,86,72} or {143,240,168}
  if powered then color(ledColor,0.17);g.circle('fill',ledX,ledY,7) end
  color(powered and ledColor or {57,65,65});g.circle('fill',ledX,ledY,2.5)
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
