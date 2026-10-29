-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local UI=require('src.ui.Gen3EmeraldDepositQuantity')
local Menu=require('src.ui.Gen3BagMenu');local S=require('src.core.SaveSerializer')
local Sound=require('src.core.Sound');local oldPlay,oldGraphics=Sound.play,love.graphics
Sound.play=function()end
local frames,texts,releases={}, {},0
local font={COLOR={NORMAL={}},measure=function(s)return#s*6 end,
 draw=function(s,x,y,opts)texts[#texts+1]={text=s,x=x,y=y,opts=opts}end}
local window={template=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end,
 stdFrame=function(r)frames[#frames+1]=r end}
love.graphics={newCanvas=function(w,h,opts)
 T.eq(w,240);T.eq(h,160);T.eq(opts.dpiscale,1)
 return{setFilter=function()end,release=function()releases=releases+1 end}
end}
local game={data={items={POTION={name='POT%ION',pocket='ITEM'},ORAN={name='ORAN BERRY',pocket='BERRY'}}},
 save={inventory={POTION=12,ORAN=999},pcItems={},unrelated='KEEP'}}
local key,current,calls,lastQty,lastName
local owner=setmetatable({game=game,emerald=true,store='deposit',message='KEEP'},Menu)
owner.emeraldView={load=function(name)
 if name=='src.ui.game3.frlg_font'then return font end
 if name=='src.ui.game3.window'then return window end
 error(name)
end,text=function(_,key,vars)T.eq(key,'count');return'x'..vars[1]end}
game.input={wasPressed=function(_,button)return key==button end}
game.stack={top=function()return current end,push=function(_,state)current=state end,
 pop=function()local state=current;current=owner;state:exit()end}
local function open(id,max)
 current=owner;calls=0;lastQty=nil;lastName=nil;frames={};texts={}
 owner:askQuantity(id or'POTION',max or 12,'Deposit how many\n{VAR1}(s)?',function(qty,name)
  calls=calls+1;lastQty=qty;lastName=name
 end)
 T.eq(getmetatable(current),UI,'the actual bag callback opens the Emerald overlay')
 return current
end
local function press(k)local state=current;key=k;state:update();key=nil end
local before=S.encode(game.save)
local state=open();T.eq(owner.message,'Deposit how many\nPOT%ION(s)?')
state:drawNative();T.eq(#frames,1);T.eq(frames[1].x,24);T.eq(frames[1].y,17)
T.eq(frames[1].w,5);T.eq(frames[1].h,2)
T.eq(texts[1].text,'x01');T.eq(texts[1].x,203);T.eq(texts[1].y,138)
T.eq(texts[1].opts.colors,font.COLOR.NORMAL)
press('down');T.eq(state.qty,12,'DOWN wraps to the selected stack limit')
press('up');T.eq(state.qty,1,'UP wraps at the selected stack limit')
press('right');T.eq(state.qty,11);press('right');T.eq(state.qty,12)
press('left');T.eq(state.qty,2);press('left');T.eq(state.qty,1)
T.eq(S.encode(game.save),before,'navigation and drawing preserve all save fields')
press('b');T.eq(current,owner);T.eq(owner.message,'KEEP');T.eq(calls,0)
T.eq(state.canvas,nil);T.eq(releases,1)
key='a';state:update();key=nil;T.eq(calls,0,'late input cannot confirm a cancelled transaction')
state=open();press('right');press('a');T.eq(calls,1);T.eq(lastQty,11);T.eq(lastName,'POT%ION')
T.eq(current,owner);T.eq(owner.message,'KEEP');T.eq(releases,2)
state:finish(1);T.eq(calls,1,'completion cannot run twice')
state=open('ORAN',999);press('down');T.eq(state.qty,999);state:drawNative()
T.eq(texts[1].text,'x999');T.eq(texts[1].x,200);T.eq(texts[1].y,138)
press('b');T.eq(calls,0);T.eq(S.encode(game.save),before)
-- The original generic path remains available without the native Emerald bag.
local Q=require('src.ui.QuantityBox');local oldNew=Q.new;local generic
Q.new=function(_,opts)generic=opts;return{}end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen'}do
 owner.emerald=false;owner.frlg=false;owner.message=nil;owner:askQuantity('POTION',12,'Own {VAR1}',function()end)
 T.eq(generic.max,12,version..' keeps its existing selector when its native path is unavailable')
 generic.onDone(nil);T.eq(owner.message,nil)
end
Q.new=oldNew;owner.emerald=true;owner.message='KEEP'
-- Real inventory IO must remove only the chosen physical stack.
local V=require('src.core.GameVersion');local oldVersion=V.get();V.set('emerald')
local Bag=require('src.inventory.Bag');local Native=require('src.inventory.Gen3RsInventory')
game.data.constants={gen=3,gen3Bag={version='emerald',pockets={ITEM=30,BERRY=46}}}
game.data.items.POTION.index=13;game.save={inventory={},bagOrder={},pcItems={}}
T.eq(Bag.add(game.save,'POTION',111,game.data),true)
local row=Native.rows(game.save,game.data,'ITEM')[2]
owner.rows={{id='POTION',qty=row.qty,rsSlot=row.slot}};owner.index=1
owner.rebuild=function()end;local message;owner.tell=function(_,text)message=text end
owner:depositItem('POTION');state=current;T.eq(state.max,12)
press('right');press('a');T.eq(game.save.pcItems.POTION,11);T.eq(game.save.inventory.POTION,100)
local rows=Native.rows(game.save,game.data,'ITEM');T.eq(rows[1].qty,99);T.eq(rows[2].qty,1)
T.check(message and#message>0,'the original completion callback still publishes its result')
V.set(oldVersion);Sound.play=oldPlay;love.graphics=oldGraphics
T.finish()
