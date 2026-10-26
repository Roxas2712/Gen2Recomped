-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Localized GBA type sprites: decode the source graphics, not translated text
-- painted over an English label. Only the independent draw adapter is ours.
local B={path='assets/generated/ui/ula_type_badges.png'}
function B.compile(rom,offsets)
 local function at(name)local row=assert(offsets[name],'Missing type sprite symbol: '..name);return type(row)=='table'and row[1]or row end
 local raw=assert(rom:lz77(at('gMoveTypes_Gfx')));if type(raw)=='table'then local s={};for i,v in ipairs(raw)do s[i]=string.char(v)end;raw=table.concat(s)end
 local count=#raw/256;assert(count==math.floor(count)and count>=18 and count<=32,'Invalid type sprite geometry')
 local palette=assert(rom:lz77(at('gMoveTypes_Pal')))
 if type(palette)=='table'then local s={};for i,v in ipairs(palette)do s[i]=string.char(v)end;palette=table.concat(s)end
 assert(#palette>=96,'Truncated type sprite palettes')
 local banks=at('sMoveTypeToOamPaletteNum')
 local image=love.image.newImageData(32,count*16)
 for frame=0,count-1 do
  local bank=rom:u8(banks+frame)-13;assert(bank>=0 and bank<=2,'Invalid type sprite palette bank')
  for y=0,15 do for x=0,31 do
   local tile=math.floor(y/8)*4+math.floor(x/8);local value=raw:byte(frame*256+tile*32+(y%8)*4+math.floor(x%8/2)+1)
   local ink=x%2==0 and value%16 or math.floor(value/16)
   local offset=(bank*16+ink)*2;local lo,hi=palette:byte(offset+1,offset+2);local color=lo+hi*256
   local r=color%32;local g=math.floor(color/32)%32;local b=math.floor(color/1024)%32
   image:setPixel(x,frame*16+y,math.floor(r*255/31+.5)/255,math.floor(g*255/31+.5)/255,math.floor(b*255/31+.5)/255,ink==0 and 0 or 1)
  end end
 end
 local bytes=image:encode('png'):getString();image:release()
 return bytes,{image=B.path,width=32,height=16,count=count}
end
function B.install(live)
 local V=require('src.core.GameVersion');if V.get()~='emerald'then return end
 local Summary=require('src.ui.Gen3SummaryMenu');local state=Summary.__ulaTypeBadges
 if state then state.live=live;return end
 state={live=live};Summary.__ulaTypeBadges=state
 local native=Summary.drawInfo
 Summary.drawInfo=function(self,...)
  local spec=self.game.data.constants.gen3Summary.typeBadges
  if not(state.live()and spec and self.hasArt)then return native(self,...)end
  local windows=self:windows();local win=windows and windows.labels[10]
  if not win then return native(self,...)end
  local types=B.types(self.def,self.game.data.type_chart)
  if not types or #types==0 then return native(self,...)end
  local old=rawget(self,'typeText');self.typeText=function()return nil end
  local ok,result=pcall(native,self,...);self.typeText=old;if not ok then error(result,0)end
  local Assets=require('src.render.Assets');local image=Assets.image(spec.image)
  love.graphics.push('all');love.graphics.setColor(1,1,1,1)
  for i,id in ipairs(types)do
   local q=love.graphics.newQuad(0,id*16,32,16,image:getDimensions())
   love.graphics.draw(image,q,win.x+32+(i-1)*36,win.y);q:release()
  end
  love.graphics.pop();return result
 end
end
function B.types(def,chart)
 if not def or not(chart and chart.types)then return nil end
 local out={};local seen={}
 for _,name in ipairs({def.type1 or(def.types and def.types[1]),def.type2 or(def.types and def.types[2])})do
  local row=chart.types[name];local id=type(name)=='number'and name or row and row.index
  if not id or id<0 or id>=18 then return nil end
  if not seen[id]then out[#out+1]=id;seen[id]=true end
 end
 return out
end
return B
