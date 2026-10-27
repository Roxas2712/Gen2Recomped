-- Native Korean glyphs occupy two tile rows. Keep changes on the active mod
-- bus and retain the engine's input, battle and save state machines.
return function(mod,encoding,fallback)
 if encoding~='korean-gen2' and encoding~='japanese-gen2' then return end
 local Font=require('src.render.Font')
 local Chrome=require('src.ui.gen2.Chrome')
 local Battle=require('src.ui.gen2.BattleState')
 local Dex=require('src.ui.gen2.PokedexMenu')
 local MainMenu=require('src.ui.gen2.MainMenu')
 local Gear=require('src.ui.gen2.Pokegear')
 local Vm=require('src.script.gen2.Vm')
 local Diploma=require('src.ui.gen2.Diploma')
 local Summary=require('src.ui.gen2.SummaryMenu')
 local BoxMenu=require('src.ui.gen2.BoxMenu')
 local Mart=require('src.ui.gen2.MartMenu')
 local Choice=require('src.ui.ChoiceBox')
 local Party=require('src.ui.gen2.PartyMenu')
 local Marquee=require('src.ui.Marquee')
 local PackMenu=require('src.ui.gen2.PackMenu')
 local PackGfx=require('src.ui.gen2.PackGfx')
 local Clock=require('src.core.gen2.Clock')
 local Palette=require('src.render.GbcPalette')
 local Strings=require('src.core.Strings')
 local Mon=require('src.battle.gen2.Mon')
 local patch=Battle.__ulaKoreanLayout
 if not patch then
  patch={bottom=Battle.drawBottom,enemy=Battle.drawEnemyHud,player=Battle.drawPlayerHud,print=Chrome.printThrough,dexBody=Dex.drawEntryBody,dexUpdate=Dex.update,clockBox=MainMenu.drawClockBox,pack=PackGfx.draw,packList=PackMenu.drawList,pink=Summary.pinkPlacements,green=Summary.greenPlacements,blue=Summary.bluePlacements,diploma=Diploma.drawPanel,pocketName=Vm.pocketName,dexText=Dex.text,dexTile=Dex.tile,gearText=Gear.text,gearMapDraw=Gear.drawMap,gearClockDraw=Gear.drawClock}
  Battle.__ulaKoreanLayout=patch
  patch.partyPanel=Party.drawPanel;patch.partyIcon=Party.drawIcon;patch.partyHp=Party.drawHpBar;patch.partySubmenu=Party.drawSubmenu;patch.chromeCursor=Chrome.cursor
  local function partyRow(i)
   local start=patch.partyStart
   if i<start or i>=start+4 then return nil end
   return 1+(i-start)*3
  end
  Party.drawPanel=function(self,...)
   if not patch.active()or patch.fontOnly then return patch.partyPanel(self,...)end
   patch.party=self;patch.partyRows=true;patch.partyStart=math.max(1,math.min(self.index-3,#self.party-3))
   local out=patch.partyPanel(self,...);patch.party=nil;patch.partyRows=false;return out
  end
  Party.drawSubmenu=function(self,...)
   patch.partyRows=false
   if patch.active()and not patch.fontOnly and self.submenu.battle then
    Chrome.box(11,10,9,8)
    for i,item in ipairs(self.submenu.items)do
     local y=12+(i-1)*2
     if i==self.submenu.index then Chrome.cursor(12,y)end
     Chrome.print(item.label,13,y)
    end
    return
   end
   return patch.partySubmenu(self,...)
  end
  Party.drawIcon=function(self,mon,x,y,...)
   if patch.party then
    for i,value in ipairs(self.party)do if value==mon then
     local row=partyRow(i);if not row then return end
     y=y-(i-1)*16+(row-1)*8;break
    end end
   end
   return patch.partyIcon(self,mon,x,y,...)
  end
  Party.drawHpBar=function(self,mon,x,y,...)
   if patch.party then local row=partyRow(y/2);if not row then return end;y=row+1 end
   return patch.partyHp(self,mon,x,y,...)
  end
  Chrome.cursor=function(x,y,...)
   if patch.party and patch.partyRows and x==0 then
    if y==1+#patch.party.party*2 then y=1+math.min(4,#patch.party.party)*3
    else y=partyRow((y+1)/2);if not y then return end end
   end
   return patch.chromeCursor(x,y,...)
  end
  patch.pcPanel=BoxMenu.drawPanel;patch.pcFrame=BoxMenu.selectionFrameRect
  patch.martYesNo=Mart.drawYesNo
  patch.choiceNew=Choice.new
  Choice.new=function(...)
   local self=patch.choiceNew(...)
   if patch.active()and not patch.fontOnly and self.firstItem<2 then
    self.ty=math.max(0,self.ty-1);self.th=self.th+1;self.firstItem=self.firstItem+1
   end
   return self
  end
  Mart.drawYesNo=function(self,choice,...)
   if not patch.active()or patch.fontOnly then return patch.martYesNo(self,choice,...)end
   Chrome.box(14,6,6,6)
   Chrome.print(Strings('YES'),16,8);Chrome.print(Strings('NO'),16,10)
   Chrome.cursor(15,choice==1 and 8 or 10)
  end
  patch.chromeBox=Chrome.box;patch.chromePrint=Chrome.print
  BoxMenu.drawPanel=function(self,...)
   patch.pc=self;local out=patch.pcPanel(self,...);patch.pc=nil;return out
  end
  BoxMenu.selectionFrameRect=function(self,row)
   local rect=patch.pcFrame(self,row)
   if patch.active()and not patch.fontOnly then
    rect.y=33+(row-1)*16;rect.h=16;rect.rounded=false
   end
   return rect
  end
  Chrome.box=function(x,y,w,h,...)
   if patch.pc and patch.active()and not patch.fontOnly then
    if x==8 and y==0 and h==3 then h=4
    elseif x==8 and y==2 and h==12 then h=13
    elseif x==0 and y==15 and h==3 then y=14;h=4 end
   end
   return patch.chromeBox(x,y,w,h,...)
  end
  Chrome.print=function(text,x,y,...)
   if patch.party and patch.partyRows then
    if x==1 and y==1+#patch.party.party*2 then y=1+math.min(4,#patch.party.party)*3
    elseif x==3 or x==13 then
     local row=partyRow((y+1)/2);if not row then return end;y=row
     if x==3 then x=4;text=Marquee.at(text,5,(patch.party.clock or 0)/60)end
    elseif x==5 or x==8 or x==12 then
     local row=partyRow(y/2);if not row then return end
     if x==5 then x=10;y=row
     elseif x==12 then x=14;y=row;text=Marquee.at(text,6,(patch.party.clock or 0)/60)
     else x=7;y=row+1 end
    end
   end
   if patch.pc and patch.active()and not patch.fontOnly then
    if x==10 and y==1 then y=2
    elseif x==9 and y>=4 and y<=12 then y=y+1
    elseif x==1 and patch.pc.message and (y==13 or y==15)then y=y+1
    elseif not patch.pc.message and x==1 and y==14 then y=13
    elseif (x==1 or x==5)and y==12 then y=11 end
   end
   return patch.chromePrint(text,x,y,...)
  end
  Vm.pocketName=function(self,...)
   local name=patch.pocketName(self,...)
   if patch.active()and not patch.fontOnly then
    local names=patch.korean and {['ITEM POCKET']='도구 포켓',['KEY POCKET']='중요한 포켓',['BALL POCKET']='볼 포켓',['TM POCKET']='기술머신 포켓'}or {['ITEM POCKET']='どうぐポケット',['KEY POCKET']='たいせつなものポケット',['BALL POCKET']='ボールポケット',['TM POCKET']='わざマシンポケット'}
    return names[name]or name
   end
   return name
  end
  Dex.text=function(self,text,x,y,...)
   if patch.active()and not patch.fontOnly and self.view=='option'and x==1 and y==15 then y=16 end
   return patch.dexText(self,text,x,y,...)
  end
  Dex.tile=function(self,id,x,y,...)
   if patch.active()and not patch.fontOnly and self.gfx and self.gfx.nativeAsianDex then
    -- The US caption end caps occupy native lettering tiles. Translated
    -- headings draw directly on the background instead of those US caps.
    if (self.view=='option'or self.view=='search')and y==1 and (id==0x3b or id==0x3c)then return end
    -- Native main-screen borders use the ordinary frame cells. US-only
    -- scrollbar/rule ids overlap native AREA/CRY captions in this atlas.
    if self.view=='list'or self.view=='results'then
     local native={[0x50]=0x35,[0x51]=0x37,[0x52]=0x3a,[0x53]=0x3a,[0x54]=0x35,[0x59]=0x35,[0x5a]=0x37,[0x5b]=0x3a,[0x66]=0x35,[0x67]=0x37,[0x68]=0x3a}
     id=native[id]or id
    end
   end
   return patch.dexTile(self,id,x,y,...)
  end
  Gear.text=function(self,text,x,y,...)
   if patch.active()and not patch.fontOnly then
    if patch.gearClock and x==12 and y==1 then text=patch.korean and ' 전환' or ' きりかえ'end
    if patch.korean and patch.gearMap then
     if x==9 and y==0 then y=1
     elseif self.fly and x==2 and y==0 then y=1
     elseif self.fly and x==2 and y==1 then x=6 end
    end
   end
   return patch.gearText(self,text,x,y,...)
  end
  Gear.drawMap=function(self,...)
   patch.gearMap=true;local out=patch.gearMapDraw(self,...);patch.gearMap=false;return out
  end
  Gear.drawClock=function(self,...)
   patch.gearClock=true;local out=patch.gearClockDraw(self,...);patch.gearClock=false;return out
  end
  Diploma.drawPanel=function(self,...)
   if not patch.active()or patch.fontOnly or not(self.gfx and self.gfx.nativeAsian)then return patch.diploma(self,...)end
   local palette=self:palette();local G=love.graphics;local batch=assert(self:batch(),'Native certificate map absent')
   Chrome.paletteFill(0,0,160,144,palette);G.setColor(1,1,1,1)
   Palette.with(palette,function()G.draw(batch,0,0)end)
   Chrome.printThrough(self.gfx.player,3,5,palette);Chrome.printThrough(self.playerName,9,5,palette)
   Chrome.printThrough(self.gfx.honorific,15,5,palette)
   local y=8
   for line in (self.gfx.certificate..'\n'):gmatch('(.-)\n')do Chrome.printThrough(line,3,y,palette);y=y+2 end
   Chrome.printThrough(self.gfx.studio,11,16,palette)
  end
  Summary.pinkPlacements=function(self,...)
   local out=patch.pink(self,...)
   if patch.active()and not patch.fontOnly then
    local infected=false
    for _,v in ipairs(out)do if v.x==1 and v.y==13 then infected=true end end
    for _,v in ipairs(out)do
     if infected and v.x==0 and v.y==12 then v.text=''
     elseif v.x==0 and v.y==14 then v.text=patch.korean and '타입/'or 'タイプ/'
     elseif v.x==6 and v.y==13 then v.y=12
     elseif v.x==1 and v.y==15 then v.x=4;v.y=14
     elseif v.x==1 and v.y==16 then v.x=4
     elseif v.x==1 and v.y==13 then v.x=0;v.y=12
     elseif v.x==14 and v.y==14 then v.x=16;v.y=15;v.text=patch.korean and '까지'or 'まで'
     elseif v.x==17 and v.y==14 then v.x=11;v.y=15 end
    end
   end
   return out
  end
  Summary.greenPlacements=function(self,...)
   local out=patch.green(self,...)
   if patch.active()and not patch.fontOnly then
    for _,v in ipairs(out)do if v.y==8 then v.y=9 elseif v.x==8 then v.x=1;v.y=v.y+1 elseif v.x==0 and v.y==10 then v.text=''end end
   end
   return out
  end
  Summary.bluePlacements=function(self,...)
   local out=patch.blue(self,...)
   if patch.active()and not patch.fontOnly then
    for _,v in ipairs(out)do
     if v.x==11 then v.y=v.y+1
     elseif patch.korean and v.y==13 and v.x<10 then v.y=14 end
    end
   end
   return out
  end
  PackMenu.drawList=function(self,x,y,...)
   if patch.active()and not patch.fontOnly and self.gfx and self.gfx.gfx and self.gfx.gfx.nativeAsianPack and y==2 then y=3 end
   return patch.packList(self,x,y,...)
  end
  patch.packSubmenu=PackMenu.drawSubmenu;patch.packYesNo=PackMenu.drawYesNo
  PackMenu.drawYesNo=function(self,...)
   if not patch.active()or patch.fontOnly then return patch.packYesNo(self,...)end
   return Mart.drawYesNo(self,self.confirm.choice)
  end
  PackMenu.drawSubmenu=function(self,...)
   if not patch.active()or patch.fontOnly then return patch.packSubmenu(self,...)end
   local menu=self.submenu;local count=#menu.rows
   local keys={use='USE',give='GIVE',toss='TOSS',sel='SEL',quit='QUIT'}
   local labels,width={},7
   for i,id in ipairs(menu.rows)do labels[i]=Strings(keys[id]or id);width=math.max(width,#Font.split(labels[i])+3)end
   local x=math.min(self:submenuColumn(),20-width)
   local bottom=(count>=5 and x==0)and 12 or 11;local top=bottom-count*2-1
   Chrome.box(x,top,width,bottom-top+1)
   for i,label in ipairs(labels)do
    local y=top+2+(i-1)*2
    if i==menu.index then Chrome.cursorThrough(x+1,y,Chrome.DEFAULT_BOX_PALETTE)end
    Chrome.printThrough(label,x+2,y,Chrome.DEFAULT_BOX_PALETTE)
   end
  end
  PackGfx.draw=function(self,pocket,...)
   if not patch.active() or patch.fontOnly or not(self.gfx and self.gfx.nativeAsianPack)then return patch.pack(self,pocket,...)end
   Chrome.paletteFill(0,0,160,144,Chrome.DEFAULT_BOX_PALETTE)
   for i=0,39 do self:menuTile(0x28+i,i%20,math.floor(i/20))end
   for y=2,11 do for x=0,5 do self:menuTile(0x24,x,y)end end
   local first=self.gfx.pocketPicture[pocket];local img=self:image('pack')
   for i=0,11 do self:blit(img,4,first+i,1+i%4,3+math.floor(i/4))end
   first=self.gfx.nativePocketName[pocket]
   for i=0,7 do self:menuTile(first+i,1+i%4,7+math.floor(i/4))end
   self:menuTile(0,0,7);self:menuTile(1,5,7);self:menuTile(2,0,8);self:menuTile(3,5,8)
  end
  MainMenu.drawClockBox=function(self,...)
   if not patch.active() or patch.fontOnly or not patch.korean then return patch.clockBox(self,...)end
   -- Korean glyphs extend one row above the baseline. Both labels share
   -- the inner baseline so the weekday cannot collide with the top border.
   Chrome.textbox(0,14,18,2)
   local hour,minute,weekday=self:clockParts()
   Chrome.print(Clock.weekdayName(weekday),1,16)
   Chrome.print(MainMenu.timeString(hour,minute),7,16)
  end
  Chrome.printThrough=function(text,x,y,...)
   if patch.active() and (not patch.fontOnly or tostring(text):find('[\128-\255]')) then
    if patch.hud=='enemy' and x==1 and y==0 then x,y=2,1
    elseif patch.hud=='player' and x==10 and y==7 then y=8 end
   end
   return patch.print(text,x,y,...)
  end
  Battle.drawEnemyHud=function(self,...)
   patch.hud='enemy';local result=patch.enemy(self,...);patch.hud=nil;return result
  end
  Battle.drawPlayerHud=function(self,...)
   patch.hud='player';local result=patch.player(self,...);patch.hud=nil;return result
  end
  Dex.drawEntryBody=function(self,row,entry,...)
   local result=patch.dexBody(self,row,entry,...)
   if patch.active() and not patch.fontOnly and not self.newEntry then
    self:blank(1,16,18,2)
    local labels=patch.korean and {'설명','분포','울음','인쇄'} or {'せつめい','ぶんぷ','こえ','いんさつ'}
    local columns={0,6,11,14}
    for i,label in ipairs(labels)do self:text(label,columns[i]+1,17)end
    if self:cursorVisible()then Chrome.cursorThrough(columns[self.entryAction or 1],17,self.gfx and self.gfx.palette,true)end
   end
   if patch.active() and not patch.fontOnly and row.caught then
    -- A Korean entry is one page. Remove the English page badge and give
    -- the native 16px lines their full area, above the action row.
    self:blank(1,9,2,2) -- remove the US PAGE badge above the native text
    self:blank(1,10,18,6)
    local y=11
    for line in (tostring(entry.text or '')..'<NEXT>'):gmatch('(.-)<NEXT>') do
     if y>15 then break end
     self:text(line,2,y);y=y+2
    end
   end
   return result
  end
  Dex.update=function(self,...)
   if patch.active() and not patch.fontOnly and self.newEntry and self.view=='entry' then
    local input=self.game and self.game.input
    if input and (input:wasPressed('a') or input:wasPressed('b')) then self.page=2 end
   end
   local result=patch.dexUpdate(self,...)
   if patch.active() and not patch.fontOnly then self.page=1 end
   return result
  end
  Battle.drawBottom=function(self,ox)
   if not patch.active() or patch.fontOnly or (self.phase~='menu' and self.phase~='moves') then return patch.bottom(self,ox) end
   if not self:bottomUIVisible() then return end
   ox=ox or 0
   local previous=Palette.setBgp(self:exitFadeBgp())
   local pal=Chrome.DEFAULT_BOX_PALETTE
   if self.phase=='menu' then
    Chrome.box(0,12,20+ox,6);self:printMessage(ox)
    local x=8+ox;Chrome.box(x,12,12,6)
    for i,label in ipairs(self:menuLabels())do
     local tx=x+2+((i-1)%2)*5;local ty=14+math.floor((i-1)/2)*2
     if i==self.menuIndex then Chrome.cursorThrough(tx-1,ty,pal)end
     Chrome.printThrough(label,tx,ty,pal)
    end
   else
    -- Native Korean core.asm: MoveSelectionScreen / MoveInfoBox.
    Chrome.box(0,8,10,10);Chrome.box(9,12,11+ox,6)
    local moves=self:playerMoves()
    for i,move in ipairs(moves)do
     local y=10+(i-1)*2
     if i==self.moveIndex then Chrome.cursorThrough(1,y,pal)
     elseif i==self.moveSwapIndex then Chrome.printThrough('▷',1,y,pal)end
     local def=self.game.data.moves[move.id]
     Chrome.printThrough(def and def.name or move.id,2,y,pal)
    end
    local move=moves[self.moveIndex]
    if move then
     local fighter=self.battle and self.battle.player
     if fighter and self.battle:moveDisabled(fighter,move.id) then Chrome.printThrough(Strings('Disabled!'),10,15,pal)
     else
      local def=self.game.data.moves[move.id]
      Chrome.printThrough(('%2d/%2d'):format(move.pp or 0,move.maxPp or Mon.maxPpOf(move,self.game.data)),14+ox,13,pal)
      Chrome.printThrough(Strings('TYPE/'),10,15,pal)
      local typ=def and def.type;local record=self.game.data.type_chart.types[typ]
      Chrome.printThrough(record and record.name or typ or '',15+ox,16,pal)
     end
    end
   end
   Palette.setBgp(previous)
  end
 end
 local active=(fallback or Font.__ulaEuropeanStrings).active
 patch.active=active;patch.korean=mod.language=='ko';patch.fontOnly=fallback~=nil
end
