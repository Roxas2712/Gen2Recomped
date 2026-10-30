-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native E/FRLG field-party presentation over authoritative host selections.
local M={};M.__index=M
function M.available(game)
 return require('src.import.Gen3NativePartyAssets').valid(game and game.data and game.data.constants
  and game.data.constants.gen3NativeParty,require('src.core.GameVersion').get())
end
function M.forHost(owner)
 return M.available(owner.game)and not(owner.battle or owner.chooseOrder or owner.noInput)
end
function M.retainStatus(game,battle,id,list)
 return not battle and M.available(game)and getmetatable(list)==require('src.ui.Gen3BagMenu')
  and require('src.inventory.Gen3FieldUse').kind(game.data,id)=='status'or false
end
function M.new(owner)
 local self=setmetatable({owner=owner,game=owner.game,images={},quads={}},M)
 local spec=self.game.data.constants.gen3NativeParty;self.version=spec.version
 local ui={party={buttons={cancel='cancel',confirm='confirm'}}}
 local text={};local load
 function text.ir(key)return assert(spec.textIR[key],'Missing native party label '..key)end
 function text.plain(key,vars)return load('src.core.game3.scripting.text_ir').toAscii(text.ir(key),vars)end
 text.translate=function(value)return value end;text.has=function(key)return spec.textIR[key]~=nil end
 if self.version=='emerald'then
  local root=require('src.import.Gen3EmeraldHallAssets').ROOT
  ui.frames={manifest=self.game.data.constants.gen3EmeraldHall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
   dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
   dialogueWindow={left=2,top=15,width=26,height=4}}
  local ctx=require('src.ui.Gen3EmeraldSceneContext').new(self.game,{ui=ui,bindings={['src.core.game3.rom_text']=text,
   ['src.import.gba.extract_island1']={CACHE_ROOT='data/generated/gba'},
   ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end}}})
  load,self.canvas=ctx.load,ctx.canvas
 else
  local session={version=self.version};local bindings=require('src.ui.Gen3FrlgSceneBindings').new(self.game,session)
  bindings['src.core.game3.profile'].forSession().ui=ui;bindings['src.core.game3.rom_text']=text
  load=require('compat.gen1-rs.Loader').new(self.version,bindings)
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 end
 self.load=load;self.font=load('src.ui.game3.frlg_font');self.chrome=load('src.ui.game3.party_chrome')
 self.window=load('src.ui.game3.window');self.chrome.install(nil,{version=self.version})
 load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(self.version=='emerald'and 19 or 9,
  ((self.game.save.options or{}).gen3Frame or 1)-1)))
 self.text=text.plain;return self
end
function M:quad(key,x,y,w,h,sw,sh)
 if not self.quads[key]then self.quads[key]=love.graphics.newQuad(x,y,w,h,sw,sh)end
 return self.quads[key]
end
function M:held(mon,x,y)
 if not mon.item then return end
 local image=self.images.held
 if not image then
  local bytes=assert(love.filesystem.read('data/generated/gba/pokemon/party/hold_icons.rgba'))
  image=love.graphics.newImage(love.image.newImageData(8,16,'rgba8',bytes));image:setFilter('nearest','nearest');self.images.held=image
 end
 local def=self.game.data.items[mon.item]or{};local n=tonumber(def.index)or tonumber(mon.item)or 0
 local frame=def.mail or(n>=121 and n<=132)
 love.graphics.setColor(1,1,1,1);love.graphics.draw(image,self:quad(frame and'mail'or'item',0,frame and 8 or 0,8,8,8,16),x-4,y-4)
end
function M:ailment(mon,hp)
 if hp<=0 then return 7 end
 local status=mon.status or mon.statusWord or mon.status1
 if type(status)=='number'then
  local function has(mask)return math.floor(status/mask)%2==1 end
  if has(8)or has(128)then return 1 end
  if has(64)then return 2 end
  if status%8~=0 then return 3 end
  if has(32)then return 4 end
  if has(16)then return 5 end
  status=nil
 end
 local code=self.chrome.statusFrameFor(status)
 if code==0 and(tonumber(mon.pokerus or mon.gen3Pokerus)or 0)%16~=0 then return 6 end
 return code
end
function M:member(i,mon)
 local owner,C,F=self.owner,self.chrome,self.font;local emerald=self.version=='emerald'
 local lead=i==1;local x,y=lead and 8 or 96,lead and 24 or(8+(i-2)*24)
 local selected=i==owner.index or owner.hpTransferFrom==mon
 local egg=mon.isEgg==true;C.drawSlot(lead and'main'or'wide',x/8,y/8,selected,egg or owner.tmhm~=nil)
 local iconX,iconY=lead and 16 or 104,lead and 40 or(18+(i-2)*24)
 local ballX,ballY=lead and 16 or 102,lead and 34 or(25+(i-2)*24)
 C.drawBall(ballX-16,ballY-16,selected and 1 or 0)
 owner:drawIcon(mon,{x=x,y=y,width=lead and 80 or 144,height=lead and 56 or 24,wide=lead,
  selected=selected,icon={x=iconX,y=iconY}})
 self:held(mon,iconX+4,iconY+10)
 local palette=i+2;local opts={small=true,colors=C.textColors(palette)}
 local function print(text,dx,dy,width)
  F.draw(tostring(text or''),x+dx,y+dy,{small=true,maxWidth=width or 56,colors=opts.colors})
 end
 local def=self.game.data.pokemon[mon.species]or{}
 print(mon.nickname or def.name or mon.species,lead and 24 or 22,lead and 11 or 3)
 if egg then return end
 local hp,max=math.max(0,mon.hp or 0),math.max(1,mon.stats and mon.stats.hp or mon.maxHp or 1)
 local heal=owner.heal;if heal and heal.mon==mon then hp=math.floor(heal.shown)end
 hp=math.min(max,hp)
 local status=self:ailment(mon,hp)
 if status==0 or status==6 then
  if require('src.ui.LevelDisplay').visible(mon,'party',self.game)then
   print(self.text('level')..tostring(mon.level or 1),lead and 32 or(emerald and 30 or 32),lead and 20 or 12,32)
  end
 end
 local sex=require('src.pokemon.Pokemon').genderOf(self.game.data,mon)
 local dex=tonumber(def.dex);local nidoran=(dex==29 or dex==32)and(not mon.nickname or mon.nickname==def.name)
 if not nidoran and(sex=='male'or sex=='female')then
  F.draw(sex=='male'and'♂'or'♀',x+(lead and 64 or(emerald and 62 or 64)),y+(lead and 20 or 12),
   {small=true,colors=sex=='male'and F.COLOR.PARTY_MALE or F.COLOR.PARTY_FEMALE})
 end
 if owner.tmhm then print(owner:learnWord(mon),lead and 12 or 77,lead and 34 or 4,64)
 else
  local nx,ny=lead and 38 or 102,lead and(emerald and 37 or 36)or 12
  print(('%3d/'):format(hp),nx,ny,24);print(('/%3d'):format(max),lead and 53 or 117,ny,24)
  local bx,by=x+(lead and 24 or 88),y+(lead and 35 or 10)
  local width=math.floor(hp*48/max);if hp>0 and width==0 then width=1 end
  local base=width>24 and 57 or width>9 and 73 or 89
  local function fill(id,xx,yy,w,h)
   if w>0 then love.graphics.setColor(C.palColor(id));love.graphics.rectangle('fill',xx,yy,w,h)end
  end
  fill(base+1,bx,by,width,1);fill(base,bx,by+1,width,2)
  fill(palette*16+13,bx+width,by,48-width,1);fill(palette*16+2,bx+width,by+1,48-width,2)
 end
 if status>0 then
  local sx=lead and(emerald and 50 or 56)or(emerald and 136 or 144)
  local sy=lead and 52 or(27+(i-2)*24);C.drawStatus(sx-16,sy-4,status)
 end
end
function M:body()
 local owner,C,F,W=self.owner,self.chrome,self.font,self.window
 C.drawBg();local party=owner:party()
 for i=1,6 do
  if party[i]then self:member(i,party[i])elseif i>1 then C.drawSlot('empty',12,1+(i-2)*3,false)end
 end
 local top=self.game.stack:top();if top and top.gbaPartyOwner==owner then return end
 if owner.submenu then
  local mon=party[owner.index];local def=mon and self.game.data.pokemon[mon.species]or{}
  local name=mon and(mon.nickname or def.name or mon.species)or''
  W.stdFrame(W.template(1,17,17,2));F.draw(self.text('action',{stringVars={name}}),10,138,{colors=F.COLOR.NORMAL})
  local n=#owner.submenu;local y=19-n*2;W.stdFrame(W.template(19,y,10,n*2))
  for i,row in ipairs(owner.submenu)do
   local py=y*8+(i-1)*16+2
   F.draw(row.label,161,py,{colors=row.move and(F.COLOR.BLUE or F.COLOR.NORMAL)or F.COLOR.NORMAL})
   if i==owner.subIndex then W.cursorPx(153,py)end
  end
 else
  W.stdFrame(W.template(1,17,21,2))
 local role=owner.tmhm and'teach'or owner.switchFrom and'move'or(owner.pickOnly or owner.hpTransferFrom)and'use'or'choose'
  F.draw(self.text(role),10,138,{colors=F.COLOR.NORMAL})
  C.drawCancelButton(184,136,owner.index>#party)
 end
end
function M:render(fn)
 local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);fn()
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:draw()return self:render(function()self:body()end)end
function M:exit()
 if self.canvas then self.canvas:release();self.canvas=nil end
 for _,q in pairs(self.quads)do q:release()end
 for _,img in pairs(self.images)do img:release()end
 self.load,self.chrome,self.font,self.window,self.images,self.quads=nil,nil,nil,nil,nil,nil
end
-- Retain TextBox's input/acknowledgment and explicit page/continuation marks,
-- but wrap the revealed text using the native dialogue face's advances.
function M:messagePages(pages)
 local result={contBefore={}};local Font=require('src.render.Font')
 for p,lines in ipairs(pages)do
  local out,conts={},{}
  for i,line in ipairs(lines)do
   local wait=pages.contBefore and pages.contBefore[p]and pages.contBefore[p][i]or false
   while true do
    local spans=Font.split(line);local used,fit=0,0
    for n,span in ipairs(spans)do
     used=used+self.font.advance(span.code or 0);if used>216 then break end;fit=n
    end
    if fit>=#spans then out[#out+1]=line;conts[#out]=wait;break end
    fit=math.max(1,fit)
    -- Never split several glyphs emitted by one source command.
    if spans[fit+1]and spans[fit+1].from==spans[fit].from then
     local first=fit;while first>1 and spans[first-1].from==spans[fit].from do first=first-1 end
     if first>1 then fit=first-1 else
      while spans[fit+1]and spans[fit+1].from==spans[fit].from do fit=fit+1 end
     end
    end
    local cut=spans[fit].to
    for n=fit,1,-1 do if line:sub(spans[n].from,spans[n].to)==' 'then cut=spans[n].to;break end end
    out[#out+1]=line:sub(1,cut);conts[#out]=wait;wait=false;line=line:sub(cut+1)
   end
  end
  result[p],result.contBefore[p]=out,conts
 end
 return result
end
function M.message(game,text,done,opts)
 local Party=require('src.ui.Gen3PartyMenu');local owner
 local states=game.stack.states or{}
 for i=#states,1,-1 do
  local s=states[i]
  if getmetatable(s)==Party and s.gbaNative and not s.battle then owner=s;break end
 end
 if not owner then return end
 local options={};for k,v in pairs(opts or{})do options[k]=v end
 options.box={tx=1,ty=15,tw=28,th=4};options.maxPixels=216
 options.uiWidth,options.uiHeight=240,160;options.textX,options.line1Y,options.line2Y=14,124,139
 options.softWrap=false;options.drawFrame=false;options.scrollDistance,options.scrollStep=15,2
 local box=require('src.render.TextBox').new(game,text,done,options)
 box.pages=owner.gbaNative:messagePages(box.pages);box.shown={};box:beginLine()
 box.gbaPartyOwner=owner;box.holdsUIAnchors=true
 box.wantsFillScale=function()return true end;box.wantsEdgeBleed=function()return false end
 box.draw=function(self)
  local view=owner.gbaNative;local F,W=view.font,view.window
  view:render(function()
   W.stdFrame(W.template(1,15,28,4));love.graphics.setScissor(14,124,216,30)
   if self.scrollPx then self.scrollPx=self.scrollPx-2;if self.scrollPx<=0 then self.scrollPx=nil end end
   for i,codes in ipairs(self.shown)do
    local x,y=14,124+(i-1)*15+(i==1 and(self.scrollPx or 0)or 0)
    for _,code in ipairs(codes)do F.drawGlyph(code,x,y,{colors=F.COLOR.NORMAL});x=x+F.advance(code)end
   end
  end)
 end
 return box
end
return M
