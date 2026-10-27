-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Layouts for complete 8x16 native glyphs on the fork's 160x144 surfaces.
-- State/input handlers stay installed; only drawing and visible row budgets
-- change. The same metrics drive cursors, scrolling and bounds checks.
local L={}
function L.partyWindow(index,count)
 local first=math.max(1,math.min(index-3,math.max(1,count-3)))
 return first,math.min(count,first+3)
end
function L.namingMetrics(m)
 m.top=48;m.lineH=16;m.left=16;m.pitch=16
 return m
end
function L.install(mod,live)
 local Font=require('src.render.Font');local Runtime=require('src.mods.Runtime')
 local state=Font.__ulaForkAsianLayout
 if state then state.live=live;return{set=function(_,language)state.language=language end}end
 state={live=live};Font.__ulaForkAsianLayout=state
 local function active()return state.live()and(state.language=='ja'or state.language=='ko')end
 local function scoped(kind,self,fn,...)
  local old=state.context;state.context={kind=kind,self=self}
  local ok,out=pcall(fn,self,...);state.context=old
  if not ok then error(out,0)end;return out
 end
 local draw,code,rectangle=Font.draw,Font.drawCode,love.graphics.rectangle
 local function mapped(text,x,y)
  local c=state.context;if not(active()and c)then return text,x,y end
  local kind,self=c.kind,c.self;local width=160-x
  if kind=='menu'then width=(self.tx+self.tw-1)*8-x
  elseif kind=='choice'then width=(self.tx+self.tw-1)*8-x
  elseif kind=='dex-entry'then
   if x==72 and y>=24 and y<=72 then y=y-16
   elseif y==88 or y==104 or y==120 then y=y-8
   elseif y==136 then y=128
   elseif x==8 and y==80 then y=72 end
   if y>=80 and y<128 then width=152-x end
  elseif kind=='dex-list'then
   if x==72 and y>=16 and y<=self.rows*16 and y%16==0 then y=16+(y/16-1)*20;width=80 end
   if y==136 then y=128;width=({[0]=16,[32]=48,[88]=16,[112]=48})[x]or width end
   if x==8 and(y==88 or y==112)then width=32 end
  elseif kind=='list'then
   if self.gen2Bag and x>=64 and y>=16 and y<=80 and y%16==0 then width=64 end
   if self.gen2Bag and x<40 and y>=56 and y<80 then width=40-x;y=60 end
   if (self.messageBox or self.dialogue or self.gen2Bag)and(y==112 or y==128)then y=y-8 end
   if y>=136 then y=128 end
  elseif kind=='battle-hud'then
   if y==0 then width=48 end
   if x==40 and y==8 then x=56;width=24 end
   if y==56 then width=40 end
  elseif kind=='battle-bottom'then
   if self.phase=='menu'and not(self.safari or self.bugContest)and x==80 and y==128 then text=require('src.core.Strings')('PACK')end
   if y>=104 then y=y-8 end
  elseif kind=='gear'then
   if y==112 or y==128 then y=y-8 end
  elseif kind=='summary-header'then width=160-x
  elseif kind=='egg'then
   if y>=112 then y=88+math.floor((y-112)/10)*16
   elseif x>=72 and y>=40 then y=y-8 end
  elseif kind=='card'then
   if x==16 and(y==16 or y==48)then width=40
   elseif x==56 and y==16 then width=56
   elseif x==16 and y==96 then width=88 end
  elseif kind=='diploma'then
   if y>=48 and y<=88 then if y==88 then width=72 end;y=48+math.floor((y-48)/10)*16
   elseif y==128 then y=124;x=96;width=56 end
   if x==24 and y==32 then width=56 end
  end
  if width<=0 then return nil end
  return Font.fit(text or'',width),math.max(0,x),math.max(0,math.min(y,128))
 end
 Font.draw=function(text,x,y)
  local t,xx,yy=mapped(text,x,y);if t==nil then return 0 end
  return draw(t,xx,yy)
 end
 Font.drawCode=function(glyph,x,y)
  local c=state.context
  if active()and c and glyph~=Font.BORDER.h and glyph~=Font.BORDER.v and glyph~=Font.BORDER.tl and glyph~=Font.BORDER.tr and glyph~=Font.BORDER.bl and glyph~=Font.BORDER.br then
   if c.kind=='battle-bottom'and y>=104 then y=y-8
   elseif c.kind=='dex-entry'and y==136 then y=128
   elseif c.kind=='gear'and(y==112 or y==128)then y=y-8 end
  end
  return code(glyph,x,y)
 end
 love.graphics.rectangle=function(mode,x,y,w,h,...)
  local c=state.context
  if active()and state.phone and x==16 and w==128 and h==8 and y>=32 and y<=56 then
   y=32+(y-32)*2;h=16
  elseif active()and c and c.kind=='card'and x==8 and y==30 and h==1 then return
  elseif active()and c and c.kind=='dex-entry'then
   if y==85 and h==2 then y=77 elseif y==78 and h==10 then y=70 end
  elseif active()and c and c.kind=='dex-list'then
   local row=c.self.index-c.self.scroll;local original=row*16;local moved=16+(row-1)*20
   if y==original-3 and h==1 then y=moved-2
   elseif y==original+10 and h==1 then y=moved+16
   elseif y==original-3 and h==14 and w==1 then y=moved-2;h=19 end
  end
  return rectangle(mode,x,y,w,h,...)
 end
 local box=Font.drawBox
 Font.drawBox=function(tx,ty,tw,th,...)
  local c=state.context
  if active()and c and c.kind=='egg'then
   if ty==0 and th==3 then th=4 elseif ty==12 and th==6 then ty=10;th=8 end
  end
  return box(tx,ty,tw,th,...)
 end
 local function wrap(module,method,kind,before)
  local cls=require(module);local fn=assert(cls[method],module..'.'..method)
  cls[method]=function(self,...)
   if not active()then return fn(self,...)end
   if before then before(self)end
   return scoped(kind,self,fn,...)
  end
 end
 local Menu=require('src.ui.Menu');local menuNew=Menu.new
 Menu.new=function(...)
  local self=menuNew(...)
  if active()and not self.gbaWindow then
   self.rowStep=math.max(2,self.rowStep);self.ty=math.min(self.ty,14)
   self.maxVisible=math.min(self.maxVisible or #self.items,math.max(1,math.floor((18-self.ty-2)/self.rowStep)))
   self.th=math.min(18-self.ty,math.max(self.th,self.maxVisible*self.rowStep+2));self:clampScroll()
  end
  return self
 end
 wrap('src.ui.Menu','draw','menu')
 local Choice=require('src.ui.ChoiceBox');local choiceNew=Choice.new
 Choice.new=function(...)
  local self=choiceNew(...)
  if active()then self.th=math.max(6,self.th);self.ty=math.max(0,math.min(self.ty,18-self.th))end
  return self
 end
 wrap('src.ui.ChoiceBox','draw','choice')
 local Naming=require('src.ui.NamingScreen');local metrics=Naming.metrics
 Naming.metrics=function(self,...)
  local m=metrics(self,...);return active()and not self.pages and L.namingMetrics(m)or m
 end
 local List=require('src.ui.ListMenu');local listNew=List.new
 List.new=function(...)
  local self=listNew(...);if active()and self.gen2Dex then self.rows=5 end;return self
 end
 wrap('src.ui.ListMenu','draw','list')
 wrap('src.ui.ListMenu','drawGen2Dex','dex-list')
 local Dex=require('src.ui.DexEntryMenu');local render=Dex.render
 Dex.render=function(game,def,sprite,owned,trueColor,view)
  if not active()then return render(game,def,sprite,owned,trueColor,view)end
  return scoped('dex-entry',{},function()return render(game,def,sprite,owned,trueColor,view)end)
 end
 wrap('src.ui.PokegearMenu','draw','gear')
 local Gear=require('src.ui.PokegearMenu')
 -- Four complete two-tile names fit the native phone plate. Keep the input
 -- controller's absolute contact index; drawing receives a local window.
 local phone=Gear.drawPhone
 Gear.drawPhone=function(self,...)
  if not active()then return phone(self,...)end
  local all=self:contacts()or{};local old=self.contact;local first=math.max(1,(old or 1)-3)
  local visible={};for i=first,math.min(#all,first+3)do visible[#visible+1]=all[i]end
  self.contact=(old or 1)-first+1
  local oldContacts=rawget(self,'contacts');self.contacts=function()return visible end
  local saved=state.phone;state.phone=true
  local ok,out=pcall(phone,self,...);state.phone=saved;self.contact=old;self.contacts=oldContacts
  if not ok then error(out,0)end;return out
 end
 local gearText=Gear.text
 Gear.text=function(self,text,x,y)
  if active()and state.phone and x==3 and y>=4 and y<=7 then y=4+(y-4)*2 end
  return gearText(self,text,x,y)
 end
 -- Selected phone contacts bypass :text, so remap those three primitives.
 local mappedBase=mapped
 mapped=function(text,x,y)
  if active()and state.phone and x==18 and y>=32 and y<=56 then y=32+(y-32)*2 end
  return mappedBase(text,x,y)
 end
 local fontCode=Font.drawCode
 Font.drawCode=function(g,x,y)
  if active()and state.phone and x==8 and y>=32 and y<=56 then y=32+(y-32)*2 end
  return fontCode(g,x,y)
 end
 local Strings=require('src.core.Strings');local Hud=require('src.render.HudTiles')
 local function text(s,x,y,width)return Font.draw(Font.fit(tostring(s or''),width or 160-x),x,y)end
 local function types(data,def,index)
  local id=def.types and def.types[index];return id and(data.type_chart.types[id]or{}).name or''
 end
 local Summary=require('src.ui.SummaryMenu')
 wrap('src.ui.SummaryMenu','drawGen2Header','summary-header')
 wrap('src.ui.SummaryMenu','drawEggPage','egg')
 local pic=Summary.drawGen2Pic
 Summary.drawGen2Pic=function(self,x,y)
  if active()and state.context and state.context.kind=='egg'and y==nil then y=24 end
  return pic(self,x,y)
 end
 wrap('src.ui.TrainerCard','drawGen2','card')
 local Diploma=require('src.ui.Diploma');local diploma=Diploma.render
 Diploma.render=function(game)
  if not active()then return diploma(game)end
  return scoped('diploma',{},function()return diploma(game)end)
 end
 local pink,green,blue=Summary.drawGen2PinkPage,Summary.drawGen2GreenPage,Summary.drawGen2BluePage
 Summary.drawGen2PinkPage=function(self,...)
  if not active()then return pink(self,...)end
  local m,d=self.mon,self.game.data;local def=d.pokemon[m.species]
  local zoned=require('src.render.PaletteFX').shader()~=nil
  Hud.drawHPBar(d,0,8,m,1,zoned);text(('%d/%d'):format(m.hp,m.stats.hp),8,72,64)
  text(Strings('STATUS/'),0,80,40);text(m.status or Strings('OK'),40,80,32)
  text(Strings('TYPE/'),0,96,72);text(types(d,def,1),8,112,64);text(types(d,def,2),8,128,64)
  text(Strings('EXP POINTS'),80,64,80);text(m.exp or 0,104,80,56)
  text(Strings('LEVEL UP'),80,96,80)
  local Growth=require('src.pokemon.Growth');local left=m.level<100 and Growth.expForLevel(def.growthRate,m.level+1)-(m.exp or 0)or 0
  text(math.max(0,left),104,112,56)
  love.graphics.setColor(.33,.33,.33,1);love.graphics.rectangle('fill',75,64,2,80);love.graphics.setColor(0,0,0,1)
  Hud.drawExpBar(d,11,16,Hud.expBarPixels(d,m),zoned)
 end
 Summary.drawGen2GreenPage=function(self,...)
  if not active()then return green(self,...)end
  local m,d=self.mon,self.game.data;local item=m.item and d.items[m.item]
  text(Strings('ITEM'),0,64,40);text(item and item.name or'---',40,64,120)
  for i=1,4 do local mv=(m.moves or{})[i];local def=mv and d.moves[mv.id];local y=64+i*16
   text(def and def.name or'-',8,y,88)
   text(mv and('%d/%d'):format(mv.pp or 0,require('src.pokemon.Pokemon').maxPP(def,mv))or'--',104,y+4,56)
  end
 end
 Summary.drawGen2BluePage=function(self,...)
  if not active()then return blue(self,...)end
  local m=self.mon;local stats=m.stats
  text('ID',0,64,72);text(('%05d'):format(m.otId or 0),8,80,64)
  text(Strings('OT/'),0,96,72);text(m.ot or self.game.save.player.name,8,112,64)
  local rows={{'ATTACK',stats.attack},{'DEFENSE',stats.defense},{'SPCL.ATK',stats.spatk or stats.special},{'SPCL.DEF',stats.spdef or stats.special},{'SPEED',stats.speed}}
  for i,r in ipairs(rows)do text(Strings(r[1]),88,48+i*16,48);text(r[2]or 0,136,52+i*16,24)end
  love.graphics.setColor(.33,.33,.33,1);love.graphics.rectangle('fill',83,64,2,80);love.graphics.setColor(0,0,0,1)
 end
 local Battle=require('src.battle.BattleState');local bottom=Battle.drawTextAreaInner
 wrap('src.battle.BattleState','drawHUDs','battle-hud')
 Battle.drawTextAreaInner=function(self,...)
  if not active()then return bottom(self,...)end
  if self.phase~='moveSelect'and self.phase~='mimicSelect'then return scoped('battle-bottom',self,bottom,...)end
  Font.drawBox(0,8,20,10);love.graphics.setColor(0,0,0,1)
  local battler=self.phase=='moveSelect'and self:menuBattler()or nil
  local moves=battler and battler.curMoves or self.mimicMoves or{};local selected=self.phase=='moveSelect'and self.moveIndex or self.mimicIndex
  for i,m in ipairs(moves)do local def=self.data.moves[m.id];local y=56+i*16
   text(def and def.name or m.id,16,y,72);if i==selected then Font.drawCode(0xED,8,y)end
   if self.moveSwapIndex==i and selected~=i then Font.drawCode(0xEC,8,y)end
  end
  local sel=moves[selected or 1];local def=sel and self.data.moves[sel.id]
  if def then
   text(Strings('PP'),96,80,56);text(('%d/%d'):format(sel.pp or 0,require('src.pokemon.Pokemon').maxPP(def,sel)),96,96,56)
   local typ=self.data.type_chart.types[def.type];text(typ and typ.name or'',96,120,56)
  end
 end
 local Party=require('src.ui.PartyMenu');local partyDraw=Party.draw;local partyPal=Party.sgbPalettes
 Party.sgbPalettes=function(self,game)
  if not active()then return partyPal(self,game)end
  local P=require('src.render.PaletteFX');local out={P.whole({{255,255,255},{170,170,170},{85,85,85},{0,0,0}})}
  local party=self.party or game.save.party;local first,last=L.partyWindow(self.index,#party)
  for i=first,last do local y=(i-first)*3;local pal=P.monPal(game.data,party[i].species,nil,require('src.pokemon.Pokemon').isShiny(party[i]));if pal then out[#out+1]=P.zone(pal,1,y,2,y+1)end end
  return out
 end
 Party.draw=function(self,...)
  if not active()then return partyDraw(self,...)end
  local g=love.graphics;g.setColor(1,1,1,1);g.rectangle('fill',0,0,160,144)
  local data=self.game.data;local party=self.party or self.game.save.party;local first,last=L.partyWindow(self.index,#party)
  for i=first,last do local m=party[i];local def=data.pokemon[m.species];local y=(i-first)*24
   if not require('src.pokemon.Party').isEgg(m)then
    local path=require('src.pokemon.Sprites').path(data,m.species,'front',{kind='party',mon=m})
    if path then local img=require('src.render.Assets').image(path);g.setColor(1,1,1,1);g.draw(img,8,y+4,0,16/img:getWidth(),16/img:getHeight())end
   end
   g.setColor(0,0,0,1);text(m.nickname or def.name,32,y,40)
   if not require('src.pokemon.Party').isEgg(m)then
    text(m.level,88,y,24);if not self.tmhm then text(m.status or'',120,y,40)end
   end
   local shown=m;if self.heal and self.heal.mon==m then shown={hp=math.floor(self.heal.shown),stats=m.stats}end
   if self.tmhm then
    local can=false;for _,id in ipairs(def.tmhm or{})do if id==self.tmhm.move then can=true end end
    text(Strings(can and'ABLE'or'NOT ABLE'),88,y+8,72)
   elseif not require('src.pokemon.Party').isEgg(m)then
    g.setColor(1,1,1,1);Hud.drawHPBar(data,5,(y+16)/8,shown,nil,false);require('src.render.PaletteFX').markTrueColor(40,y+16,56,8)
    g.setColor(0,0,0,1);text(('%d/%d'):format(shown.hp,m.stats.hp),104,y+16,56)
   end
   if i==self.index then Font.drawCode(0xED,0,y+8)end
   if i==self.swapFrom or i==self.softboiledFrom then Font.drawCode(0xEC,16,y+8)end
  end
  Font.drawBox(0,12,20,6);g.setColor(0,0,0,1)
  local prose=require('src.render.TextBox').substitute(self.game,Strings(self:bottomMessage()))
  local pages=require('src.render.TextBox').paginate(prose,18)
  for i,line in ipairs(pages[1]or{})do if i<=2 then text(line,8,88+i*16,144)end end
  if self.submenu then
   local n=math.min(7,#self.subItems);local start=math.max(1,self.subIndex-n+1);local ty=16-n*2
   Font.drawBox(9,ty,11,n*2+2);g.setColor(0,0,0,1)
   for i=1,n do text(self.subItems[start+i-1].label,88,(ty+1)*8+(i-1)*16,64)end
   Font.drawCode(0xED,80,(ty+1)*8+(self.subIndex-start)*16)
  end
  g.setColor(1,1,1,1)
 end
 return{set=function(_,language)state.language=language end}
end
return L
