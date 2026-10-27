-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Independent presentation adapter. Native input, moves and save data remain
-- owned by the host. All lettering and sprite pixels come from imported ROMs.
local S={}
local wordKeys={cancel='gText_Cancel2',info='gText_Info',switch='gText_Switch',level='gText_LevelSymbol',number='gText_NumberClear01'}
wordKeys.accuracy='gText_Accuracy2';wordKeys.power='gText_Power';wordKeys.appeal='gText_Appeal';wordKeys.jam='gText_Jam'
for _,key in ipairs{'Cancel','Page','PageCancel','PageDetail','Pick','PickSwitch','PickDelete'}do wordKeys[key]='gText_PokeSum_Controls_'..key end
function S.words(named,strings)
 local out={};for key,label in pairs(wordKeys)do local text=named[label];if text then out[key]=(strings or{})[text]or text end end
 return out
end
function S.englishWords(bytes,addresses,own)
 local IR=own('vendor/src/core/game3/scripting/text_ir.lua');local T=own('@host/gba_text.lua');local named={}
 for _,label in pairs(wordKeys)do local at=addresses[label];if at then named[label]=T.plain(IR.decode(bytes:sub(at+1,at+257),{dialect='frlg'}),'firered')end end
 return named
end
local function stringBytes(value)
 if type(value)=='string'then return value end
 local out={};for i,v in ipairs(value)do out[i]=string.char(v)end;return table.concat(out)
end
function S.resources(rom,offsets,game,english)
 local files,spec={},{images={}}
 local function at(name)local v=assert(offsets[name],'Missing summary resource '..name);return type(v)=='table'and v[1]or v end
 local function palette(raw)
  raw=stringBytes(raw);local p={}
  for i=0,#raw/2-1 do local lo,hi=raw:byte(i*2+1,i*2+2);local c=lo+hi*256
   p[i]={math.floor((c%32)*255/31+.5)/255,math.floor((math.floor(c/32)%32)*255/31+.5)/255,math.floor((math.floor(c/1024)%32)*255/31+.5)/255,1}
  end;return p
 end
 local function image(key,raw,w,h,p,bank)
  raw=stringBytes(raw);assert(#raw>=w*h/2,'Truncated summary sprite '..key)
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do
   local tile=math.floor(y/8)*(w/8)+math.floor(x/8)
   local byte=assert(raw:byte(tile*32+(y%8)*4+math.floor(x%8/2)+1))
   local ink=x%2==0 and byte%16 or math.floor(byte/16)
   local c=p[(bank or 0)*16+ink]or{0,0,0,0};d:setPixel(x,y,c[1],c[2],c[3],ink==0 and 0 or(c[4]or 1))
  end end
  local path='assets/generated/ui/ula_summary_'..key..'.png';files[path]=d:encode('png'):getString();d:release();spec.images[key]=path
 end
 if game=='emerald'then
  local pal=palette(rom:lz77(at('gSummaryScreen_Pal')));spec.palette=pal
  local pp=palette(rom:bytes(at('gPPTextPalette'),30));for i=0,14 do pal[129+i]=pp[i]end
  spec.textColors=rom:bytes(at('pokemon_summary_screen.o:sTextColors'),39)
  if offsets.gSpeciesInfo then spec.noFlip={};for i=0,411 do if rom:u8(at('gSpeciesInfo')+i*28+25)>=128 then spec.noFlip[i]=true end end end
  image('buttons',rom:bytes(at('pokemon_summary_screen.o:sButtons_Gfx'),256),16,32,pal,7)
  image('markings',rom:bytes(at('sMonMarkings_Gfx'),2048),32,128,palette(rom:bytes(at('sMarkings_Pal'),32)))
  local raw=stringBytes(rom:lz77(at('gSummaryMoveSelect_Gfx')))
  image('selector',raw,16,#raw/8,palette(rom:lz77(at('gSummaryMoveSelect_Pal'))))
 else
  -- FireRed text.c's keypad sheet is non-lettering UI shared by the regional
  -- builds. Decode it from the exact English base, not a shipped bitmap.
  local p={[0]={0,0,0,0},[1]={1,1,1,1},[2]={98/255,98/255,98/255,1},[3]={213/255,213/255,205/255,1},[4]={230/255,8/255,8/255,1},[5]={1,189/255,115/255,1},[6]={32/255,156/255,8/255,1},[7]={148/255,246/255,148/255,1},[8]={49/255,82/255,205/255,1},[9]={164/255,197/255,246/255,1}}
  image('keypad',assert(english):sub(0x1EA701,0x1EA700+2048),128,32,p)
 end
 return files,spec
end
function S.detail(self)return self.moveSelect==true or type(self.choose)=='table'end
function S.dexNumber(data,save,mon)
 local def=data.pokemon and data.pokemon[mon.species];if not def then return nil end
 local rec=data.constants and data.constants.gen3HoennDex
 if not(save and save.nationalDex)and rec and rec.numbers then
  local n=rec.numbers[mon.species];return n and n>=1 and n<=(rec.native or 202)and n or nil
 end
 return tonumber(def.dex)
end
function S.ppColor(cur,max)
 if cur==max then return 12 end
 if cur<=0 then return 11 end
 if cur<=(max<=7 and 1 or math.floor(max/4))then return 10 end
 if cur<=(max<=7 and 2 or math.floor(max/2))then return 9 end
 return 12
end
function S.moveType(def,chart,contest)
 if not def then return nil end
 if contest then local n=def.contestCategory or def.contestType
  if type(n)=='string'then n=({COOL=0,BEAUTY=1,CUTE=2,SMART=3,TOUGH=4})[n:upper()]end
  return type(n)=='number'and n>=0 and n<=4 and 18+n or nil
 end
 local t=def.type;local row=chart and chart.types and chart.types[t]
 local id=type(t)=='number'and t or row and row.index
 return type(id)=='number'and id>=0 and id<18 and id or nil
end
function S.install(live)
 local V=require('src.core.GameVersion');if V.generation()~=3 then return end
 local Menu=require('src.ui.Gen3SummaryMenu');if Menu.__ulaSummaryParity then Menu.__ulaSummaryParity.live=live;return end
 local state={live=live};Menu.__ulaSummaryParity=state
 local Font=require('src.render.Font');local Assets=require('src.render.Assets');local Strings=require('src.core.Strings')
 local function active(self)return state.live()and self.game.data.constants.ulaSummaryParts end
 local function image(self,key)local p=self.game.data.constants.ulaSummaryParts;return p and p.images[key]and Assets.image(p.images[key])end
 local function crop(img,x,y,w,h,dx,dy,sx,sy)
  local q=love.graphics.newQuad(x,y,w,h,img:getDimensions());love.graphics.setColor(1,1,1,1)
  local ok,why=pcall(love.graphics.draw,img,q,dx or x,dy or y,0,sx or 1,sy or 1);q:release();if not ok then error(why,0)end
 end
 local function text(s,x,y,budget,ink,shadow)
  s=tostring(s or'');local scale=math.min(1,(budget or 240-x)/math.max(1,Font.width(s)))
  love.graphics.push('all');love.graphics.translate(x,y);love.graphics.scale(scale,1);love.graphics.setColor(1,1,1,1)
  local two=Font.beginTwoTone(ink or{0,0,0,1},shadow or{.65,.65,.65,1})
  local ok,why=pcall(Font.draw,s,0,0);if two then Font.endTwoTone()end;love.graphics.pop();if not ok then error(why,0)end
 end
 local function words(self)return self.game.data.constants.ulaSummaryWords or{}end
 local function help(self,frlg)
  local w=words(self);local detail=S.detail(self);local s
  if frlg then
   local key=self.isEgg and'Cancel'or type(self.choose)=='table'and'PickSwitch'or self.page==1 and'PageCancel'or self.page==2 and'Page'or detail and'PickSwitch'or'PageDetail'
   s=w[key];if not s then return end
  else
   if type(self.choose)=='table'then return end
   local label=self.page==1 and(w.cancel or Strings('CANCEL'))or self.page>=3 and(detail and w.switch or w.info)
   if not label then return end;s='{A_BUTTON}'..label
  end
  local icons=frlg and{A_BUTTON={0,0,8,12},B_BUTTON={8,0,8,12},DPAD_LEFT={112,0,8,12},DPAD_RIGHT={120,0,8,12},DPAD_LEFTRIGHT={8,16,8,12},DPAD_UPDOWN={0,16,8,12},DPAD_ANY={16,16,8,12}}or{A_BUTTON={0,0,16,16},B_BUTTON={0,16,16,16}}
  local img=image(self,frlg and'keypad'or'buttons');local segments={};local width=0;local pos=1
  while pos<=#s do
   local a,b,tag=s:find('{([A-Z_]+)}',pos)
   if a~=pos then local value=s:sub(pos,a and a-1 or #s);segments[#segments+1]={text=value,w=Font.width(value)};width=width+segments[#segments].w end
   if not a then break end
   local icon=icons[tag];if icon then segments[#segments+1]={icon=icon,w=icon[3]};width=width+icon[3]end;pos=b+1
  end
  local x=238-width
  for _,seg in ipairs(segments)do if seg.icon and img then local r=seg.icon;crop(img,r[1],r[2],r[3],r[4],x,0)
   elseif seg.text then text(seg.text,x,1,seg.w,frlg and{1,1,1,1}or{0,0,0,1})end;x=x+seg.w end
 end
 local header=Menu.drawHeader
 Menu.drawHeader=function(self,...)
  local parts=active(self);local rec=self.game.data.constants.gen3Summary
  if not(parts and V.get()=='emerald'and self.hasArt and rec and rec.pageArt and self.mon and not self.mon.isEgg)then return header(self,...)end
  local bg=Assets.image(rec.pageArt.info);local detail=S.detail(self)and self.page>=3
  if not detail then
   love.graphics.setColor(parts.palette[15]);love.graphics.rectangle('fill',0,16,80,144)
   if rec.pageArt.panel then crop(Assets.image(rec.pageArt.panel),0,16,80,144)end
   crop(bg,0,16,80,144)
   love.graphics.setColor(parts.palette[15]);love.graphics.rectangle('fill',0,144,80,16)
  end
  -- The leftmost strip contains only the top bar's palette, no lettering.
  crop(bg,0,0,1,16,0,0,240,1)
  love.graphics.setColor(parts.palette[72]);love.graphics.rectangle('fill',152,0,88,15)
  love.graphics.setColor(parts.palette[71]);love.graphics.rectangle('fill',152,15,88,1)
  self:drawPagination()
  text(self.pages[self.page],2,1,86,{1,1,1,1});help(self,false)
  local mon,def=self.mon,self.def or{};local w=words(self)
  local dex=S.dexNumber(self.game.data,self.game.save,mon)
  if dex then text((w.number or'')..('%03d'):format(dex),8,17,32,{1,1,1,1})end
  text(mon.nickname or def.name or mon.species,8,97,72,{1,1,1,1})
  if not detail and not self.isEgg then
   text('/'..(def.name or tostring(mon.species)),8,113,72,{1,1,1,1})
   text((w.level or'Lv')..tostring(mon.level or 1),32,129,32,{1,1,1,1})
   local mark=self:genderMark();if mark then text(mark,65,129,14,mark=='♀'and{1,.3,.4,1}or{.3,.4,1,1})end
   local balls=self.game.data.constants.gen3BallAnim;local path=balls and balls.images and balls.images.balls
   if path then local sheet=Assets.image(path);local id=type(mon.ball)=='number'and mon.ball or require('src.battle.Gen3BallAnim').ballIndex(self.game.data,mon.ball,self.game.data.items)
    local size=balls.size or 16;id=math.max(0,math.min(math.floor(sheet:getHeight()/size)-1,id or 0));crop(sheet,0,id*size,size,size,8,128)
   end
  end
  local marks=image(self,'markings');if marks then crop(marks,0,(tonumber(mon.markings)or 0)%16*8,32,8,44,22)end
  if self.pic then
   local pic=self.picAnim and self.picAnim:image()or self.pic;local width,height=self.pic:getDimensions()
   love.graphics.push('all')
   local index=tonumber(def.index)
   if parts.noFlip and index and index>=0 and index<=411 and not parts.noFlip[index]then love.graphics.translate(80,0);love.graphics.scale(-1,1)end
   local ok,why=pcall(self.drawMon,self,pic,40-width/2,64-height/2);love.graphics.pop();if not ok then error(why,0)end
  end
 end
 local moves=Menu.drawMoves
 Menu.drawMoves=function(self,contest,...)
  if not(active(self)and V.get()=='emerald'and self.hasArt and self.game.data.constants.gen3Summary.typeBadges)then return moves(self,contest,...)end
  local data=self.game.data;local badge=Assets.image(data.constants.gen3Summary.typeBadges.image)
  local offered=type(self.choose)=='table'and self:chooseRows()or nil
  local count=offered or 4;local rows=self.mon and self.mon.moves or{}
  if count==5 then
   local rec=data.constants.gen3Summary;local page=rec.pageArt and rec.pageArt[contest and'contest_moves'or'battle_moves']
   if page then local art=Assets.image(page);crop(art,80,80,160,16,80,96);crop(art,80,104,160,8,80,112)end
  end
  for i=1,count do
   local slot=rows[i];local id=i==offered and self.choose.move or type(slot)=='table'and slot.id or slot
   local def=id and data.moves[id];local y=33+(i-1)*16
   text(def and def.name or tostring(id or'-'),120,y,72,{1,1,1,1})
   if def then
    local pp=type(slot)=='table'and slot.pp or def.pp;local max=require('src.pokemon.Pokemon').maxPP(def,slot)
    local value=Strings('PP')..tostring(pp or'-')..'/'..tostring(max or def.pp or'-')
    local parts=active(self);local colors=parts.textColors;local color=S.ppColor(tonumber(pp)or 0,tonumber(max)or def.pp or 1)
    local ink=colors and parts.palette[128+colors[color*3+2]];local shadow=colors and parts.palette[128+colors[color*3+3]]
    text(value,236-Font.width(value),y,44,ink,shadow)
    local t=S.moveType(def,data.type_chart,contest);if t then crop(badge,0,t*16,32,16,85,y-1)end
   else text('--',212,y,24)end
  end
  if S.detail(self)then
   local index=self.moveIndex or 1;local slot=rows[index]
   local id=index==offered and self.choose and self.choose.move or type(slot)=='table'and slot.id or slot
   local def=id and data.moves[id]
   if def then
    if contest then
     text(words(self).appeal or Strings('APPEAL'),8,121,40);text(words(self).jam or Strings('JAM'),8,137,40);self:drawHearts(def)
    else
     text(words(self).power or Strings('POWER'),8,121,49);text(tostring(def.power or'---'),61,121,18)
     text(words(self).accuracy or Strings('ACCURACY'),8,137,49);text(tostring(def.accuracy or'---'),61,137,18)
    end
    self:drawDescription(contest and def.contestDescription or def.description,121,137)
   end
   local img=image(self,'selector');if img then
    local function selectRow(row,edge,mid)
     local y=32+(row-1)*16
     for x=80,224,16 do local frame=(x==80 or x==224)and edge or mid
      crop(img,0,frame*16,16,16,x==224 and 240 or x,y,x==224 and-1 or 1,1)
     end
    end
    if self.moveSwapFrom then selectRow(self.moveSwapFrom,6,7)end;selectRow(self.moveIndex or 1,4,5)
   end
  end
 end
 local fr=Menu.drawFireRed
 Menu.drawFireRed=function(self,...)
  local out=fr(self,...);if active(self)then
   local small=Font.hasFace('small');if small then Font.pushFace('small')end
   local ok,why=pcall(help,self,true);if small then Font.popFace()end;if not ok then error(why,0)end
  end;return out
 end
end
return S
