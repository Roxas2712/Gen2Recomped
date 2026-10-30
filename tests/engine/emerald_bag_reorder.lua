-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');love.filesystem.load=loadfile
local V=require('src.core.GameVersion');local oldV=V.get();V.set('emerald')
local N=require('src.inventory.Gen3RsInventory');local S=require('src.core.SaveSerializer')
local UI=require('src.ui.Gen3BagMenu');local Sound=require('src.core.Sound')
local oldPlay=Sound.play;local cues=0;Sound.play=function()cues=cues+1 end
local data={constants={gen3Bag={version='emerald',pockets={ITEM=30,KEY_ITEM=30,BALL=16,TM_HM=64,BERRY=46}}},items={
 POTION={index=13,pocket='ITEM',name='POTION'},ANTIDOTE={index=14,pocket='ITEM',name='ANTIDOTE'},
 ROD={index=100,pocket='KEY_ITEM',name='ROD',registrability=1},LETTER={index=101,pocket='KEY_ITEM'},
 BALL={index=4,pocket='BALL'},BERRY={index=133,pocket='BERRY'},TM01={index=289,pocket='TM_HM'}}}
local function fresh()
 return{inventory={POTION=100,ANTIDOTE=2,ROD=1,LETTER=1,BALL=4,BERRY=999,TM01=1},
  bagOrder={'POTION','ROD','ANTIDOTE','LETTER','BALL','BERRY','TM01'},registeredItem='ROD',
  options={gen3Frame=20},flags={KEEP=true},party={{species='TREECKO',hp=15}},
  gen3RsBagSlots={format=1,version='emerald',pockets={
   ITEMS={{id='POTION',qty=99},{id='ANTIDOTE',qty=2},{id='POTION',qty=1}},
   KEY_ITEMS={{id='ROD',qty=1},{id='LETTER',qty=1}},POKE_BALLS={{id='BALL',qty=4}},
   TM_CASE={{id='TM01',qty=1}},BERRY_POUCH={{id='BERRY',qty=999}}}}}
end
for from=1,3 do for to=1,4 do
 local save=fresh();local before=S.encode(save);local rows=N.rows(save,data,'ITEM')
 local expected=S.encode(rows);T.eq(S.encode(save),before,'reading move provenance never migrates the save')
 local handled,changed=N.moveBefore(save,data,'ITEM',from,to,expected)
 T.eq(handled,true);local target=to>from and to-1 or to;T.eq(changed,target~=from)
 local predicted=assert(S.decode(expected));table.insert(predicted,target,table.remove(predicted,from))
 local actual=N.rows(save,data,'ITEM')
 for i,row in ipairs(predicted)do T.eq(actual[i].id,row.id);T.eq(actual[i].qty,row.qty)end
 T.eq(S.encode(save.inventory),S.encode(fresh().inventory),'insertion never combines duplicate stacks')
 T.eq(S.encode(save.party),S.encode(fresh().party));T.eq(save.registeredItem,'ROD');T.eq(save.flags.KEEP,true)
 if not changed then T.eq(S.encode(save),before,'same and adjacent targets do not even initialize a mirror')end
 local disk=assert(S.decode(S.encode(save)));T.eq(S.encode(N.rows(disk,data,'ITEM')),S.encode(actual))
end end
for _,bad in ipairs{{0,2},{1,0},{4,1},{1,5},{1,1.5},{math.huge,1},{1,0/0}}do
 local save=fresh();local before=S.encode(save)
 local handled,changed=N.moveBefore(save,data,'ITEM',bad[1],bad[2],S.encode(N.rows(save,data,'ITEM')))
 T.eq(handled,true);T.eq(changed,false);T.eq(S.encode(save),before)
end
for _,pocket in ipairs{'TM_HM','BERRY'}do
 local save=fresh();local before=S.encode(save)
 local _,changed=N.moveBefore(save,data,pocket,1,2,S.encode(N.rows(save,data,pocket)))
 T.eq(changed,false);T.eq(S.encode(save),before,'numbered pockets cannot be moved')
end
do
 local save=fresh();local expected=S.encode(N.rows(save,data,'ITEM'))
 save.inventory.POTION=99;local before=S.encode(save)
 local _,changed=N.moveBefore(save,data,'ITEM',1,4,expected)
 T.eq(changed,false);T.eq(S.encode(save),before,'stale quantities reject the entire transaction')
end
local key;local game={data=data,save=fresh(),input={wasPressed=function(_,k)return k==key end},stack={pop=function()error('Unexpected close')end}}
local owner=UI.new(game,{pocket='ITEM'});owner.emerald=true
local function nativeCursor(delta)
 owner.index=math.max(1,math.min(#owner.rows,owner.index+delta))
end
owner.moveCursor=function(_,delta)nativeCursor(delta)end
local function press(k)key=k;owner:update();key=nil end
local before=S.encode(game.save);press('select');T.eq(owner.emeraldSwap.from,1);T.eq(cues>0,true)
press('right');T.eq(owner.pocket,1,'pocket switching is blocked while moving')
press('down');press('b');T.eq(owner.emeraldSwap,nil);T.eq(owner.index,1)
T.eq(S.encode(game.save),before,'B cancels without touching inventory/order/registration')
press('select');for _=1,3 do press('down')end
T.eq(owner:selected().close,true);press('a');T.eq(owner.index,3)
T.eq(owner.rows[1].id,'ANTIDOTE');T.eq(owner.rows[2].qty,1);T.eq(owner.rows[3].qty,99)
T.eq(game.save.registeredItem,'ROD','moving ordinary items preserves registered stable ID')
before=S.encode(game.save);owner.index=#owner.rows;press('select')
T.eq(owner.emeraldSwap,nil);T.eq(S.encode(game.save),before,'CLOSE cannot become a movable item')
owner=UI.new(game,{pocket='KEY_ITEM'});owner.emerald=true;owner.moveCursor=function(_,d)nativeCursor(d)end
before=S.encode(game.save);press('select');T.eq(owner.emeraldSwap.from,1);T.eq(game.save.registeredItem,'ROD')
press('b');T.eq(S.encode(game.save),before,'SELECT in KEY ITEMS never toggles registration')
for _,opts in ipairs{{pick=true},{sell=true},{store='deposit'},{itemPc=true},{rows={{id='POTION',qty=99}}},{noInput=true}}do
 opts.pocket='ITEM';owner=UI.new(game,opts);owner.emerald=true;press('select');T.eq(owner.emeraldSwap,nil,'special contexts never start a move')
end
owner=UI.new(game,{pocket='ITEM',battle={}});owner.emerald=true;press('select')
T.check(owner.emeraldSwap,'ordinary battle bag permits reordering');press('b')
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do
 V.set(version);local save=fresh();local raw=S.encode(save)
 local foreign={constants={gen3Bag={version=version}},items=data.items}
 T.eq(N.moveBefore(save,foreign,'ITEM',1,3,''),false);T.eq(S.encode(save),raw)
end
Sound.play=oldPlay;V.set(oldV)
T.finish('Emerald physical bag insertion, duplicate stacks, cancel, CLOSE, stale input and contexts')
