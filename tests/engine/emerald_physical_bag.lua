-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');love.filesystem.load=loadfile
local Bag=require('src.inventory.Bag');local Native=require('src.inventory.Gen3RsInventory')
local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
local old=V.get();V.set('emerald')
local function data(version,pockets)
  local c={gen=3,gen3Bag={version=version,pockets=pockets or{ITEM=30,KEY_ITEM=30,BALL=16,TM_HM=64,BERRY=46}}}
  if version=='ruby'or version=='sapphire'then c.gen3RsBag={format=1,version=version}end
  return{constants=c,items={POTION={index=13,pocket='ITEM',name='POTION'},
    ANTIDOTE={index=14,pocket='ITEM',name='ANTIDOTE'},POKE_BALL={index=4,pocket='BALL'},
    CHERI_BERRY={index=133,pocket='BERRY'},TM01={index=289,pocket='TM_HM'},
    HM01={index=339,pocket='TM_HM',machine={kind='HM'}}}}
end
local function snapshot(version,rows)
  return{format=1,version=version,pockets={ITEMS=rows,KEY_ITEMS={},POKE_BALLS={},TM_CASE={},BERRY_POUCH={}}}
end
local d=data('emerald');local save={inventory={POTION=99,BOULDERBADGE=1},bagOrder={'POTION'},options={}}
local before=S.encode(save)
T.eq(#Native.rows(save,d,'ITEM'),1);T.eq(S.encode(save),before,'legacy projection never migrates a save during reads')
T.eq(Bag.canAdd(save,'POTION',1,d),true);T.eq(S.encode(save),before,'capacity query preserves the complete legacy save')
T.eq(Bag.add(save,'POTION',1,d),true,'ordinary items spill into another 99-item slot')
local rows=Native.rows(save,d,'ITEM');T.eq(#rows,2);T.eq(rows[1].qty,99);T.eq(rows[2].qty,1)
T.eq(save.inventory.POTION,100);T.eq(save.inventory.BOULDERBADGE,1)
T.eq(Bag.remove(save,'POTION',10,d,rows[1].slot),true)
rows=Native.rows(save,d,'ITEM');T.eq(rows[1].qty,89);T.eq(rows[2].qty,1)
before=S.encode(save);T.eq(Bag.remove(save,'POTION',2,d,rows[2].slot),false,'selected slot cannot borrow from another duplicate')
T.eq(S.encode(save),before,'refused selected removal is atomic')
local handled,ok=Native.swap(save,d,rows[1].slot,rows[2].slot)
T.eq(handled,true);T.eq(ok,true);rows=Native.rows(save,d,'ITEM');T.eq(rows[1].qty,1);T.eq(rows[2].qty,89)
T.eq(Native.consistent(assert(S.decode(S.encode(save))),d),true,'serialized physical order survives a host round trip')
local g={data=d,save=save,stack={pop=function()end}}
before=S.encode(save);local menu=require('src.ui.Gen3BagMenu').new(g,{pocket='ITEM'})
T.eq(#menu.rows,3);T.eq(menu.rows[1].qty,1);T.eq(menu.rows[2].qty,89)
T.eq(menu.rows[1].rsSlot.index,1);T.eq(menu.rows[2].rsSlot.index,2);T.eq(menu.rows[3].close,true)
T.eq(S.encode(save),before,'opening duplicate rows never mutates their inventory/order')
local fragmented={inventory={POTION=30},bagOrder={'POTION'},gen3RsBagSlots=snapshot('emerald',{})}
for i=1,30 do fragmented.gen3RsBagSlots.pockets.ITEMS[i]={id='POTION',qty=1}end
T.eq(Native.consistent(fragmented,d),true);T.eq(Bag.pocketSlots(fragmented,'ITEM',d),30)
before=S.encode(fragmented)
T.eq(Bag.canAdd(fragmented,'ANTIDOTE',1,d),false,'preflight counts actual occupied slots, not a flattened/repacked inventory')
T.eq(Bag.add(fragmented,'ANTIDOTE',1,d),false);T.eq(S.encode(fragmented),before)
T.eq(Bag.canAdd(fragmented,'POTION',1,d),true);T.eq(S.encode(fragmented),before)
T.eq(Bag.add(fragmented,'POTION',1,d),true);T.eq(Native.rows(fragmented,d,'ITEM')[1].qty,2)
T.eq(Bag.add(save,'CHERI_BERRY',999,d),true);before=S.encode(save)
T.eq(Bag.add(save,'CHERI_BERRY',1,d),false);T.eq(S.encode(save),before,'berries remain one 999-item slot')
T.eq(Bag.add(save,'POKE_BALL',100,d),true);rows=Native.rows(save,d,'BALL');T.eq(rows[1].qty,99);T.eq(rows[2].qty,1)
T.eq(Bag.add(save,'HM01',1,d),true);T.eq(Bag.add(save,'TM01',1,d),true)
rows=Native.rows(save,d,'TM_HM');T.eq(rows[1].id,'TM01');T.eq(rows[2].id,'HM01')
local Codec=require('src.save_convert.Gen3Save');local J=require('src.link.Json')
for _,version in ipairs{'emerald','ruby','sapphire','firered','leafgreen'}do
  local f=assert(io.open('tools/rom_manifest_'..version..'.json'));local m=J.decode(f:read('*a'));f:close()
  if not m.saveFields.saveBlock2 then
    -- Use the production layout completion that FRLG's intentionally sparse
    -- manifests require, just as a real import does (no invented offsets).
    local extractor=setmetatable({manifest=m,version=version},{__index=require('src.import.RomExtractorGen3')})
    function extractor:beginStage()end
    function extractor:write()end
    for _,name in ipairs{'berryTreeSaveBlock','mauvilleSaveBlock','decorationCapacities',
      'berryPowderField','battlePointsField','dewfordPaintingField'}do
      extractor[name]=function()return nil,'not part of bag fixture'end
    end
    extractor:extractSaveLayout()
  end
  Codec.setLayout(m.save,m.substructOrders,m.saveFields,version);V.set(version)
  local caps={};for i,name in ipairs(Codec.POCKET_ORDER)do caps[name]=m.saveFields.bag.capacities[i]end
  local own=data(version,caps)
  local s={inventory={POTION=27,ANTIDOTE=1,CHERI_BERRY=999},bagOrder={'POTION','ANTIDOTE'},
    gen3RsBagSlots=snapshot(version,{{id='POTION',qty=20},{id='ANTIDOTE',qty=1},{id='POTION',qty=7}})}
  s.gen3RsBagSlots.pockets.BERRY_POUCH={{id='CHERI_BERRY',qty=999}}
  local raw=Codec.encode(s,own);local blocks=assert(Codec.readBlocks(raw))
  local rawBag=Codec.bag(blocks.block1,Codec.encryptionKey(blocks.block2))
  local supported=version=='emerald'or version=='ruby'or version=='sapphire'
  T.eq(#raw,Codec.SAVE_SIZE);T.eq(#rawBag[1],supported and 3 or 2,version..' cartridge slot count')
  T.eq(rawBag[1][1].item,13);T.eq(rawBag[1][1].count,supported and 20 or 27)
  T.eq(rawBag[1][2].item,14);T.eq(rawBag[1][2].count,1)
  if supported then T.eq(rawBag[1][3].item,13);T.eq(rawBag[1][3].count,7)end
  local loaded=Codec.decode(raw,own)
  T.eq(loaded.inventory.POTION,27);T.eq(loaded.inventory.CHERI_BERRY,999)
  if supported then
    T.eq(Native.consistent(loaded,own),true,version..' imported snapshot agrees with canonical goods')
    rows=Native.rows(loaded,own,'ITEM');T.eq(rows[1].qty,20);T.eq(rows[2].id,'ANTIDOTE');T.eq(rows[3].qty,7)
    local again=Codec.decode(Codec.encode(loaded,own),own)
    rows=Native.rows(again,own,'ITEM');T.eq(rows[1].qty,20);T.eq(rows[3].qty,7,'second export preserves partial physical slots')
  else T.eq(loaded.gen3RsBagSlots,nil,version..' keeps its existing single-stack representation')end
end
-- Exercise the actual bag -> party -> field-use callback, rather than
-- calling Bag.remove directly with a selection the UI may fail to forward.
local f=dofile('tests/gba_item_use/fixture.lua').new('.','gen2','emerald',3,'unified',true)
f.game.data.constants.gen3Bag=data('emerald').constants.gen3Bag
f.game.save.inventory={};f.game.save.bagOrder={}
local potion=f.id.POTION
T.eq(Bag.add(f.game.save,potion,150,f.game.data),true)
local owner,picker=f.nativePicker('POTION',2)
T.eq(owner:selected().rsSlot.index,2);T.eq(owner:selected().qty,51)
before=S.encode(f.game.save);f.press('b')
T.eq(f.game.stack:top(),owner);T.eq(S.encode(f.game.save),before,'party cancel preserves both physical stacks')
owner:act('use',potion);f.press('a')
rows=Native.rows(f.game.save,f.game.data,'ITEM')
T.eq(f.mon.hp,35);T.eq(rows[1].qty,99);T.eq(rows[2].qty,50,'medicine consumes the selected second stack')
for _=1,500 do if f.game.stack:top()==owner then break end;f.press('a')end
T.eq(f.game.stack:top(),owner,'medicine returns to its actual bag owner')
T.eq(owner:selected().qty,50)
-- The normal bag sale callback bounds the quantity to the selected row;
-- refusing an out-of-date selection must never award money.
owner.sell=true;local sale,question
local Q=require('src.ui.QuantityBox');local B=require('src.render.TextBox')
f.patch(Q,'new',function(_,opts)sale=opts;return{}end)
f.patch(B,'new',function(_game,_text,_done,opts)question=opts;return{}end)
owner:choose();T.eq(sale.max,50,'sale quantity is the physical stack, not aggregate goods')
sale.onDone(3);local cash=f.game.save.money or 0;question.choice(false)
T.eq(f.game.save.money or 0,cash);rows=Native.rows(f.game.save,f.game.data,'ITEM');T.eq(rows[2].qty,50)
owner:choose();sale.onDone(3)
question.choice(true);rows=Native.rows(f.game.save,f.game.data,'ITEM')
T.eq(rows[1].qty,99);T.eq(rows[2].qty,47);T.eq(f.game.save.money,cash+150)
owner.sell=nil;local deposit
f.patch(owner,'askQuantity',function(_self,_id,max,_prompt,done)deposit={max=max,done=done}end)
f.patch(owner,'tell',function()end)
owner:depositItem(potion);T.eq(deposit.max,47)
deposit.done(2,'POTION');rows=Native.rows(f.game.save,f.game.data,'ITEM')
T.eq(rows[1].qty,99);T.eq(rows[2].qty,45);T.eq(f.game.save.pcItems[potion],2)
f.game.save.pcItems[potion]=999;owner:depositItem(potion);before=S.encode(f.game.save)
deposit.done(1,'POTION');T.eq(S.encode(f.game.save),before,'full PC refusal preserves both physical stacks')
owner.sell=true
owner:choose();sale.onDone(3);before=S.encode(f.game.save)
-- A mod or other owner may replace the selected slot before confirmation.
f.game.save.gen3RsBagSlots.pockets.ITEMS[2].id=f.id.SUPER_POTION
f.game.save.inventory[potion]=99;f.game.save.inventory[f.id.SUPER_POTION]=45
before=S.encode(f.game.save);question.choice(true)
T.eq(S.encode(f.game.save),before,'stale sale selection neither pays nor removes replacement goods')
f.close()
V.set(old)
T.finish('Emerald physical bag slots, selected quantities, atomic capacity and all-five cartridge save round trips')
