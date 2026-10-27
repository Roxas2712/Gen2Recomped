-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Scoped corrections around installed renderers. State, input, rules and save
-- values remain owned by the host; no host renderer implementation is copied.
local L={}
function L.packMenu(menu,item,pack,inContest)
 if not inContest then for _,row in ipairs(menu.items)do if row.label==item then row.label=pack;return end end end
end
function L.commandColumns(leftWidth,rightWidth)
 local right=math.min(128,152-rightWidth)
 local left=math.min(80,right-leftWidth-8)
 return math.max(16,left),math.max(32,right)
end
function L.visibleRows(rows,index,limit)
 local first=math.max(1,math.min(index-limit+1,math.max(1,#rows-limit+1)))
 local visible={};for i=first,math.min(#rows,first+limit-1)do visible[#visible+1]=rows[i]end
 return visible,index-first+1,first
end
function L.wrap(text,width,measure)
 local rows,line={},''
 for word in tostring(text):gmatch('%S+')do
  local nextLine=line==''and word or line..' '..word
  if line~=''and measure(nextLine)>width then rows[#rows+1]=line;line=word else line=nextLine end
 end
 if line~=''then rows[#rows+1]=line end
 return rows
end
-- LoadStatsScreenPals updates color 0 of palettes 0/2 after the initial
-- _CGB_StatsScreenHPPals setup. Keep the native species/HP/EXP ink colors.
-- Reference: pret/pokegold engine/gfx/color.asm, LoadStatsScreenPals.
function L.statusZones(zones,tint)
 if not zones or not zones[1]or not tint then return zones end
 local function palette(colors)
  if type(colors)~='table'then return colors end
  local out={};for i,v in ipairs(colors)do out[i]=v end;out[1]=tint;return out
 end
 local out={zones[1],{colors=palette(zones[1].colors),x=0,y=64,w=160,h=80}}
 for i=2,#zones do
  local z=zones[i]
  if z.y>=64 and z.colors then
   local copy={};for k,v in pairs(z)do copy[k]=v end;copy.colors=palette(z.colors);out[#out+1]=copy
  else out[#out+1]=z end
 end
 return out
end
function L.hud(font)
 local h=font and font.hud
 if h and h.statsTilesBase and h.statsTilesCount and h.statsTilesBase<=0x40 and h.statsTilesBase+h.statsTilesCount>0x41 then
  -- Retail stats_screen.asm writes $40/$41; older host imports omit these
  -- metadata fields and otherwise fall back to the HP label's sheet.
  h.statsExpCapLeft=h.statsExpCapLeft or 0x40
  h.statsExpCapRight=h.statsExpCapRight or 0x41
 end
end
function L.install(live)
 local Font=require('src.render.Font');local V=require('src.core.GameVersion');local Strings=require('src.core.Strings')
 local state=Font.__ulaForkUiLayout
 if state then state.live=live;return {set=function(_,language)state.language=language end}end
 state={live=live,language='en'};Font.__ulaForkUiLayout=state
 local function active()return state.live()and state.language~='ja'and state.language~='ko'end
 local draw,width,code,box=Font.draw,Font.width,Font.drawCode,Font.drawBox
 local function localized(text,c)
  if type(text)~='string'or c.names[text]then return text end
  local strings=c.game.data.strings or{};local translated=strings[text]
  if translated then return translated end
  if c.kind=='gba-battle'and text:match('^PP%s+%d')and strings.PP then return strings.PP..text:sub(3)end
  if c.kind=='card'then
   local key,tail=text:match('^(MONEY)/(.*)$');if not key then key,tail=text:match('^(TIME)/(.*)$')end
   if key and strings[key]then return strings[key]..'/'..tail end
  end
  return text
 end
 local function scope(kind,self,fn,...)
  if not active()then return fn(self,...)end
  local old=state.context;local names={};local game=self.game
  local seen={}
  local function protect(row,depth)
   if type(row)~='table'or seen[row]or depth>4 then return end;seen[row]=true
   for _,key in ipairs({'nickname','ot','otName','name'})do if type(row[key])=='string'then names[row[key]]=true end end
   local def=row.species and game.data.pokemon[row.species];if def and def.name then names[def.name]=true end
   for k,v in pairs(row)do if type(k)=='number'and type(v)=='table'then protect(v,depth+1)end end
   for _,key in ipairs({'mon','mons','slots','pokemon'})do protect(row[key],depth+1)end
  end
  protect(game.save.party,0);protect(game.save.boxes,0);protect(self.mon,0)
  protect(self.player,0);protect(self.enemy,0)
  for _,name in pairs(game.save.boxNames or{})do if type(name)=='string'then names[name]=true end end
  local player=game.save.player or{};if player.name then names[player.name]=true end
  local c={kind=kind,self=self,game=game,names=names};state.context=c
  if kind=='battle'and self.phase=='menu'and not(self.safari or self.bugContest)then
   local item=V.generation()==2 and'PACK'or'ITEM'
   local left=math.max(width(Strings('FIGHT')),width(Strings(item)))
   local right=math.max(16,width(Strings('RUN')));c.left,c.right=L.commandColumns(left,right)
  end
  if kind=='start'then
   c.menuRight=64
   for _,row in ipairs(self.rows)do c.menuRight=math.max(c.menuRight,math.min(232,16+width(localized(row.label,c))))end
  end
  if kind=='gba-battle'then
   c.moveLabels={};local chooser=(self.menuBattler and self:menuBattler())or self.player
   for _,slot in ipairs(chooser and chooser.curMoves or{})do local def=game.data.moves[slot.id];if def then c.moveLabels[def.name]=true end end
  end
  local ok,out=pcall(fn,self,...);state.context=old
  if not ok then error(out,0)end
  return out
 end
 Font.width=function(text,...)
  local c=state.context;if active()and c then text=localized(text,c)end
  return width(text,...)
 end
 Font.draw=function(text,x,y,...)
  local c=state.context;if not(active()and c)then return draw(text,x,y,...)end
  text=localized(text,c)
  local limit=(V.generation()==3 and 240 or 160)-x
  if c.kind=='gba-battle'and c.moveLabels[text]and c.self.phase=='moveSelect'then limit=64
  elseif c.kind=='battle'and c.left then
   if x==80 then
    if y==128 and V.generation()==2 then text=Strings('PACK')end
    x=c.left
   elseif x==128 then x=c.right end
   limit=152-x
  elseif c.kind=='summary'then
   if V.generation()==2 and c.self.page==2 and x==64 and y>=80 and width(text)>96 then x=56;limit=104 end
   if V.generation()==3 then
    if c.memoRows then for i,line in ipairs(c.memoRows)do if text==line and y>=110 then y=115+(i-1)*(V.get()=='firered'and 14 or 12);break end end end
    if V.get()=='firered'then
     if x==167 then limit=71 end
     if c.self.page==3 and x==7 and y>=98 then limit=108 end
    elseif x>=84 then limit=238-x
    elseif x<80 then limit=80-x end
   end
  elseif c.kind=='start'and not c.self.savePanel then
   local record=c.game.data.constants.gen3StartMenu
   limit=(record and record.layout=='frlg'and 232 or c.menuRight)-x
  elseif c.kind=='menu'then limit=(c.self.tx+c.self.tw-1)*8-x
  elseif c.kind=='bag'then limit=152-x
  end
  -- Preserve every character; only overflowing text is condensed. Names and
  -- numeric values stay stored exactly as supplied by the native game.
  local w=width(text);local scale=math.min(1,math.max(1,limit)/math.max(1,w))
  if scale<1 then
   love.graphics.push();love.graphics.translate(x,y);love.graphics.scale(scale,1)
   local ok,result=pcall(draw,text,0,0,...);love.graphics.pop();if not ok then error(result,0)end;return result
  end
  return draw(text,x,y,...)
 end
 local fit=Font.fit
 if fit then Font.fit=function(text,pixels,...)
  local c=state.context
  if active()and c and c.kind=='gba-battle'and c.self.phase=='moveSelect'and pixels==64 and c.moveLabels[text]then return text end
  return fit(text,pixels,...)
 end end
 Font.drawCode=function(glyph,x,y,...)
  local c=state.context
  if active()and c and c.kind=='battle'and c.left then
   if glyph==0xED then if x==72 then x=c.left-8 elseif x==120 then x=c.right-8 end
   elseif glyph==0xE1 and x==128 then x=c.right
   elseif glyph==0xE2 and x==136 then x=c.right+8 end
  end
  return code(glyph,x,y,...)
 end
 Font.drawBox=function(tx,ty,tw,th,...)
  local c=state.context
  if active()and c and c.left and tx==8 and ty==12 and tw==12 then tx=math.floor(c.left/8)-2;tw=20-tx end
  if active()and c and c.kind=='start'and tx==0 and tw==9 then tw=math.ceil((c.menuRight+8)/8)end
  return box(tx,ty,tw,th,...)
 end
 local function wrap(module,method,kind)
  local t=require(module);local native=t[method];assert(type(native)=='function',module..'.'..method)
  t[method]=function(self,...)return scope(kind,self,native,...)end
 end
 wrap('src.ui.Menu','draw','menu')
  local Start=require('src.ui.StartMenu');local create=Start.new
  Start.new=function(game,...)
   local menu=create(game,...)
   if state.live()and V.generation()==2 then
    L.packMenu(menu,Strings('ITEM'),Strings('PACK'),require('src.world.BugContest').active(game.save))
   end
   return menu
  end
 if V.generation()==2 then
  local Summary=require('src.ui.SummaryMenu');local pals=Summary.sgbPalettes
  Summary.sgbPalettes=function(self,...)
   local zones=pals(self,...)
   if state.live()and not self.isEgg then
    local page=Summary.GEN2_PAGE_PALS[self.page]
    return L.statusZones(zones,page and page[2])
   end
   return zones
  end
  local native=Summary.draw
  Summary.draw=function(self,...)
   local previous=state.statusSummary;state.statusSummary=state.live()and not self.isEgg and self or nil
   local ok,result=pcall(native,self,...);state.statusSummary=previous
   if not ok then error(result,0)end;return result
  end
  local rectangle=love.graphics.rectangle
  love.graphics.rectangle=function(mode,x,y,w,h,...)
   if state.live()and state.statusSummary and mode=='fill'and
    ((x==0 and y==59 and w==160 and h==2)or(y==64 and h==80 and w==2 and(x==75 or x==83)))then
    local r,g,b,a=love.graphics.getColor();love.graphics.setColor(0,0,0,a)
    local ok,result=pcall(rectangle,mode,x,y,w,h,...);love.graphics.setColor(r,g,b,a)
    if not ok then error(result,0)end;return result
   end
   return rectangle(mode,x,y,w,h,...)
  end
 end
 if V.generation()<3 then
  wrap('src.ui.OptionsMenu','draw','options')
  wrap('src.ui.SummaryMenu','draw','summary');wrap('src.ui.PartyMenu','draw','party')
  wrap('src.ui.ListMenu','draw','bag');wrap('src.ui.TrainerCard','draw','card')
  wrap('src.battle.BattleState','drawTextAreaInner','battle')
 else
  wrap('src.ui.Gen3SummaryMenu','draw','summary')
  wrap('src.battle.Gen3Battle','draw','gba-battle')
  wrap('src.ui.Gen3Options','draw','options')
  local Start=require('src.ui.Gen3StartMenu');local startDraw=Start.draw
  Start.draw=function(self,...)
   if not active()or self.savePanel then return startDraw(self,...)end
   local rows,index=self.rows,self.index
   local visible,selected=L.visibleRows(rows,index,9);self.rows,self.index=visible,selected
   local ok,result=pcall(scope,'start',self,startDraw,...)
   self.rows,self.index=rows,index
   if not ok then error(result,0)end
   return result
  end
  local Party=require('src.ui.Gen3PartyMenu');local native=Party.draw
  Party.draw=function(self,...)
   local result=scope('party',self,native,...)
   if active()and not(self.tmhm or self.chooseOrder or self.hpTransferFrom or self.submenu)then
    local prompt=Strings('Choose a POKéMON.')
    Font.drawBox(0,16,23,4);love.graphics.setColor(0,0,0,1)
    local w=Font.width(prompt);love.graphics.push();love.graphics.translate(8,137);love.graphics.scale(math.min(1,168/math.max(1,w)),1)
    local ok,err=pcall(Font.draw,prompt,0,0);love.graphics.pop();love.graphics.setColor(1,1,1,1)
    if not ok then error(err,0)end
   end
   return result
  end
  local Summary=require('src.ui.Gen3SummaryMenu');local memo=Summary.memoLines
  Summary.memoLines=function(self,...)
   local lines=memo(self,...)
   if not active()then return lines end
   local budget=V.get()=='firered'and 224 or 144
   -- Use the full memo window before choosing line breaks. Retail templates
   -- contain short text-printer lines that needlessly overflow this host.
   local text=table.concat(lines,' ');local rows=L.wrap(text,budget,Font.width)
   while #rows>3 do budget=budget+8;rows=L.wrap(text,budget,Font.width)end
   local c=state.context;if c and c.self==self then c.memoRows=rows end
   return rows
  end
 end
 return {set=function(_,language)state.language=language end}
end
return L
