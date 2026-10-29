-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local A=require('src.import.Gen3EmeraldItemPcAssets')
local BagAssets=require('src.import.Gen3EmeraldBagAssets');local UI=require('src.ui.Gen3EmeraldItemStorage')
local V=require('src.core.GameVersion');local Fs=require('src.import.CacheFs')
local W,S=require('src.import.LuaWriter'),require('src.core.SaveSerializer')
local Loader=require('compat.gen1-rs.Loader');local Context=require('src.ui.Gen3EmeraldSceneContext')
local oldV,oldRead,oldLoad,oldContext,oldGraphics=V.get(),Fs.read,love.filesystem.load,Context.new,love.graphics
love.filesystem.load=loadfile;V.set('emerald')
local native=Loader.new('emerald',{['src.core.GameVersion']=require('src.import.Gen3EmeraldCreditsAssets').versionBinding()})
local symbols=native('src.import.gba.syms').of('emerald')
local IR=native('src.core.game3.scripting.text_ir');local starts={}
for _,name in ipairs(A.labels)do starts[assert(symbols.off(name))]=true end
local x={version='emerald',_constants={},manifest={saveFields={bag={pcItemCount=50}}},
 beginStage=function()end,write=function()end,rom={u8=function(_,at)return starts[at]and 0xBB or 255 end}}
A.extract(x);local spec=x._constants.gen3EmeraldItemPc
T.eq(A.valid(spec,'emerald'),true,'the actual selected symbol/decoder graph produces all PC labels')
Fs.read=function()return W.encode({gen3EmeraldItemPc=spec})end
T.eq(#A.missing('emerald'),0)
for _,name in ipairs(A.labels)do
 local value=spec.textIR[name];spec.textIR[name]=nil
 T.eq(A.valid(spec,'emerald'),false,'every original label is required: '..name);spec.textIR[name]=value
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do
 T.eq(A.valid(spec,version),false);T.eq(#A.missing(version),0)
end
local capacity=spec.capacity;spec.capacity=49;T.eq(#A.missing('emerald'),1);spec.capacity=capacity
local ownText={gText_WithdrawItem='WITHDRAW ITEM',gText_TossItem='TOSS ITEM',gText_Cancel2='CANCEL',
 gText_xVar1='x{STR_VAR_1}',gText_WithdrawXItems='Withdrew {STR_VAR_2} {STR_VAR_1}',
 gText_WithdrawHowManyItems='How many {STR_VAR_1}?',gText_NoItems='No items.',
 gText_NoRoomInBag='No room.',gText_ConfirmTossItems='Toss {STR_VAR_2} {STR_VAR_1}?'}
for _,name in ipairs(A.labels)do spec.textIR[name]=IR.fromAscii(ownText[name]or name)end
local bagSpec={format=1,version='emerald',manifest=BagAssets.ROOT..'manifest.lua',resources={}}
for _,name in ipairs(BagAssets.files)do bagSpec.resources[#bagSpec.resources+1]=BagAssets.ROOT..name end
for _,name in ipairs(BagAssets.fonts)do bagSpec.resources[#bagSpec.resources+1]=BagAssets.FONTS..name end
local data={constants={gen=3,gen3Bag={version='emerald',pockets={ITEM=30,BERRY=46,KEY_ITEM=30,BALL=16,TM_HM=64}},
 gen3EmeraldBag=bagSpec,gen3EmeraldItemPc=spec,gen3EmeraldHall={manifest='OWN'},gen3ItemIcons={count=377}},
 items={POTION={index=13,pocket='ITEM',name='POTION',description='Heals HP.'},
 ANTIDOTE={index=14,pocket='ITEM',name='ANTIDOTE'},ORAN={index=139,pocket='BERRY',name='ORAN BERRY'}}}
local frames,texts,cursors,icons,frameOption,releases={}, {}, {}, {},nil,0
local font={measure=function(text)return#text*6 end,face=function()return{height=16}end,linePitch=function()return 16 end,
 draw=function(text,px,py,opts)texts[#texts+1]={text=text,x=px,y=py,opts=opts}end}
local window={template=function(a,b,c,d)return{left=a,top=b,width=c,height=d}end,
 stdFrame=function(r)frames[#frames+1]=r end,fill=function()end,
 printPx=function(text,px,py)texts[#texts+1]={text=text,x=px,y=py}end,
 cursorPx=function(px,py)cursors[#cursors+1]={x=px,y=py}end,optionHeight=function()return 16 end}
love.graphics={setColor=function()end,rectangle=function()end}
Context.new=function(_,opts)
 local bindings=opts.bindings
 bindings['src.core.game3.profile']={forSession=function()return{id='emerald'}end}
 bindings['src.ui.game3.frlg_font']=font;bindings['src.ui.game3.window']=window
 bindings['src.ui.game3.chrome']={setFrameType=function(n)frameOption=n end}
 bindings['src.core.game3.audio']={playSe=function()end};bindings['src.core.game3.se_ids']={SE_SELECT=5}
 bindings['src.core.game3.rom_text']={plain=function(key,ctx)return IR.toAscii(assert(opts.textIR[key]),ctx)end}
 return{load=Loader.new('emerald',bindings),canvas={release=function()releases=releases+1 end}}
end
local current,key,closed;local game={data=data,save={}}
local parent={gen3PlayerPC=true};local alreadyHidden={gen3PlayerPC=true,hidden=true};local unrelated={}
game.input={wasPressed=function(_,button)return key==button end,isDown=function()return false end}
game.stack={states={parent,alreadyHidden,unrelated},top=function()return current end,
 pop=function()local state=current;current=nil;state:exit()end}
local function reset(save,toss)
 game.save=save;closed=0;frames={};texts={};cursors={};icons={}
 T.eq(UI.available(game),true)
 current=UI.new(game,{toss=toss,onCancel=function()closed=closed+1 end})
 current:enter();T.eq(parent.hidden,true);T.eq(alreadyHidden.hidden,true);T.eq(unrelated.hidden,nil)
 current.drawIcon=function(_,n,px,py)icons[#icons+1]={index=n,x=px,y=py}end
 return current
end
local function press(button)local state=current;key=button;state:update();key=nil end
local save={inventory={POTION=1},bagOrder={'POTION'},pcItems={POTION=12,ANTIDOTE=3,ORAN=999},
 pcOrder={'POTION','ANTIDOTE','ORAN'},options={gen3Frame=20},unrelated='KEEP'}
local before=S.encode(save);local state=reset(save)
T.eq(S.encode(save),before,'opening native storage preserves host data')
T.eq(frameOption,19,'saved frame choice reaches the original chrome')
state.ui.draw();T.eq(S.encode(save),before,'drawing native lists preserves the full save')
local list;for _,r in ipairs(frames)do if r.left==16 then list=r end end
T.check(list);T.eq(list.top,1);T.eq(list.width,13);T.eq(list.height,18)
T.eq(cursors[1].x,128);T.eq(cursors[1].y,17)
T.eq(icons[1].index,13);T.eq(icons[1].x,8);T.eq(icons[1].y,64)
local label;for _,row in ipairs(texts)do if row.text=='POTION'then label=row end end
T.check(label);T.eq(label.x,136);T.eq(label.y,17);T.eq(label.opts.font,'narrow')
press('a');T.eq(state.ui.state,'quantity');frames={};texts={};state.ui.draw()
local quantity;for _,r in ipairs(frames)do if r.left==8 and r.top==9 then quantity=r end end
T.check(quantity);T.eq(quantity.width,6);T.eq(quantity.height,2)
local count;for _,row in ipairs(texts)do if row.text=='x001'then count=row end end
T.check(count);T.eq(count.x,76);T.eq(count.y,73)
press('right');T.eq(state.ui.quantity,11);press('a');T.eq(state.ui.state,'remove')
T.eq(save.pcItems.POTION,1);T.eq(save.inventory.POTION,12)
press('a');T.eq(state.ui.state,'list');T.eq(save.pcItems.POTION,1,'result acknowledgement does not remove twice')
press('a');T.eq(state.ui.state,'remove','single item bypasses the picker')
T.eq(save.pcItems.POTION,nil);T.eq(save.inventory.POTION,13)
press('a');T.eq(state.ui.state,'list');T.eq(state.tx.store.items[1].id,14)
local goods=S.encode(save.pcItems);press('select');T.eq(state.ui.state,'swap')
press('down');press('down');press('a');T.eq(state.ui.state,'list')
T.eq(save.pcOrder[1],'ORAN');T.eq(S.encode(save.pcItems),goods,'SELECT reorders without changing quantities')
press('b');T.eq(current,nil);T.eq(closed,1);T.eq(state.canvas,nil)
T.eq(parent.hidden,nil);T.eq(alreadyHidden.hidden,true);T.eq(unrelated.hidden,nil)
state=reset({inventory={},bagOrder={},pcItems={ORAN=999},pcOrder={'ORAN'}},true)
press('a');press('down');T.eq(state.ui.quantity,999);press('a');T.eq(state.ui.state,'yesno')
before=S.encode(game.save);press('b');T.eq(S.encode(game.save),before);T.eq(state.ui.state,'list')
press('a');press('right');press('a');press('a');T.eq(state.ui.state,'remove')
T.eq(game.save.pcItems.ORAN,988);press('a');T.eq(game.save.pcItems.ORAN,988)
press('a');press('right');press('a');game.save.pcItems.ORAN=1;before=S.encode(game.save)
press('a');T.eq(state.ui.state,'error');T.eq(S.encode(game.save),before,'stale YES refuses a false successful toss')
press('a');press('b');T.eq(current,nil)
data.constants.gen3Bag.pockets.ITEM=1
state=reset({inventory={POTION=99},bagOrder={'POTION'},pcItems={ANTIDOTE=3}})
before=S.encode(game.save);press('a');press('a');T.eq(state.ui.state,'error')
T.eq(S.encode(game.save),before,'a full bag refuses the entire withdrawal')
press('a');press('b')
game.save.pcItems={UNKNOWN=1};T.eq(UI.available(game),false,'unknown imported items keep the legacy non-destructive path')
game.save.pcItems={POTION=1000};T.eq(UI.available(game),false)
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do V.set(version);T.eq(UI.available(game),false)end
T.eq(releases,3,'every closed native storage releases its owned canvas')
-- The original default transaction configuration remains usable for both RS games.
for _,version in ipairs{'ruby','sapphire'}do
 V.set(version)
 local rs={data={items=data.items,constants={gen=3,gen3RsBag={format=1,version=version},
  gen3Bag={version=version,pockets={ITEM=20,KEY_ITEM=20,BALL=16,TM_HM=64,BERRY=46}}}},
  save={inventory={POTION=5},bagOrder={'POTION'},pcItems={POTION=12}}}
 local tx=require('src.inventory.Gen3RsItemPcTransaction').new(rs)
 T.eq(tx.valid,true);T.eq(tx.policy.pcItems,50);T.eq(tx.policy.pcSlotMax,999)
 T.eq(tx:withdraw(13,3),true);T.eq(rs.save.inventory.POTION,8);T.eq(rs.save.pcItems.POTION,9)
 local row=require('src.inventory.Gen3RsInventory').rows(rs.save,rs.data,'ITEM')[1]
 T.eq(tx:deposit(row.slot,2),true);T.eq(rs.save.inventory.POTION,6);T.eq(rs.save.pcItems.POTION,11)
 T.eq(tx:toss(13,2),true);T.eq(rs.save.pcItems.POTION,9)
 local raw=S.encode(rs.save);T.eq(tx:withdraw(13,10),false);T.eq(S.encode(rs.save),raw)
end
V.set(oldV);Fs.read=oldRead;love.filesystem.load=oldLoad;Context.new=oldContext;love.graphics=oldGraphics
T.finish('Emerald original PC windows, controller, atomic transfers, reorder and stale-state refusal')
