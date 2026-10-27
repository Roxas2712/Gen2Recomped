love=require('tests.love_stub');love.filesystem.load=loadfile
local Bag=require('src.inventory.Bag')
local Model=require('src.inventory.Gen3RsInventory')
local S=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion')
local n=0
local function check(value,why)n=n+1;assert(value,why)end
local function same(before,save,why)check(before==S.encode(save),why)end
for _,version in ipairs({'ruby','sapphire'})do
  V.set(version)
  local data={constants={gen3RsBag={format=1,version=version}},items={
    POTION={index=13,pocket='ITEM'},ANTIDOTE={index=14,pocket='ITEM'},
    POKE_BALL={index=4,pocket='BALL'},GREAT_BALL={index=3,pocket='BALL'},
    CHERI_BERRY={index=133,pocket='BERRY'},CHESTO_BERRY={index=134,pocket='BERRY'},
    TM01={index=289,pocket='TM_HM'},HM01={index=339,pocket='TM_HM',machine={kind='HM'}},
  }}
  for i=1,20 do data.items['EXTRA_'..i]={index=400+i,pocket='ITEM'}end
  local save={inventory={POTION=99,BOULDERBADGE=1},bagOrder={'POTION'}}
  local inv,order=save.inventory,save.bagOrder
  local before=S.encode(save)
  check(#Model.rows(save,data,'ITEM')==1,'Old saves project without migration writes')
  same(before,save,'Read-only rows preserve all save bytes')
  check(Bag.add(save,'POTION',1,data),'99 ordinary items can spill into a new slot')
  local rows=Model.rows(save,data,'ITEM')
  check(#rows==2 and rows[1].qty==99 and rows[2].qty==1,'Original 99/1 physical rows')
  check(inv==save.inventory and order==save.bagOrder and inv.POTION==100 and inv.BOULDERBADGE==1,
    'Existing aggregate/order identities and badges retained')
  check(Model.consistent(save,data),'Stable serialized slots match authoritative aggregate')
  check(Bag.remove(save,'POTION',10,data,rows[1].slot),'Remove only selected first stack')
  check(Bag.add(save,'POTION',9,data),'Top up first stack')
  rows=Model.rows(save,data,'ITEM')
  check(rows[1].qty==98 and rows[2].qty==1,'Partially filled duplicate stacks stay separate')
  check(Bag.remove(save,'POTION',9,data,rows[1].slot),'Create two partial stacks')
  rows=Model.rows(save,data,'ITEM');check(rows[1].qty==89 and rows[2].qty==1,'Physical partial stacks preserved')
  check(Bag.add(save,'POTION',9,data),'First partial stack filled first')
  rows=Model.rows(save,data,'ITEM')
  local handled,ok=Model.swap(save,data,rows[1].slot,rows[2].slot)
  check(handled and ok,'Native SELECT swaps physical slots')
  rows=Model.rows(save,data,'ITEM');check(rows[1].qty==1 and rows[2].qty==98,'Duplicate ID swap preserves quantities')
  check(Bag.remove(save,'POTION',2,data,rows[2].slot),'Selected second slot removal succeeds')
  rows=Model.rows(save,data,'ITEM');check(rows[1].qty==1 and rows[2].qty==96,'Second-slot mutation does not consume first')
  before=S.encode(save)
  check(not Bag.remove(save,'POTION',2,data,rows[1].slot),'Cannot borrow from another stack for selected action')
  same(before,save,'Failed selected removal is atomic')
  local wrong={pocket='ITEMS',index=1,id='ANTIDOTE'}
  check(not Bag.remove(save,'POTION',1,data,wrong),'Stale stable ID selection refused')
  same(before,save,'Stale callback changes nothing')
  check(Bag.add(save,'CHERI_BERRY',999,data),'RS berry stack holds 999')
  check(Bag.stackLimit('CHERI_BERRY',data)==999 and Bag.stackLimit('POTION',data)==99,'Native per-slot limits')
  before=S.encode(save)
  check(not Bag.add(save,'CHERI_BERRY',1,data),'Berries cannot split beyond 999')
  same(before,save,'Overflow preserves every save byte')
  check(Bag.add(save,'HM01',1,data)and Bag.add(save,'TM01',1,data),'Machines added')
  rows=Model.rows(save,data,'TM_HM')
  check(rows[1].id=='TM01'and rows[2].id=='HM01','RS machines sorted by ID without FRLG HM-first rule')
  local full={inventory={POTION=99*19+1},bagOrder={'POTION'}}
  check(#Model.rows(full,data,'ITEM')==20,'Physical capacity counts duplicate slots')
  before=S.encode(full)
  check(not Bag.add(full,'ANTIDOTE',1,data),'Twenty occupied item slots refuse new ID')
  same(before,full,'Refused full-pocket add does not migrate old save')
  check(Bag.add(full,'POTION',98,data),'Existing partial slot fills even in full pocket')
  before=S.encode(full)
  check(not Bag.add(full,'POTION',1,data),'Twenty full stacks refuse extra quantity')
  same(before,full,'Full duplicate-stack overflow is atomic')
  local ball={inventory={POKE_BALL=99*16},bagOrder={'POKE_BALL'}}
  check(Bag.pocketSlots(ball,'BALL',data)==16,'Original sixteen ball slots')
  before=S.encode(ball);check(not Bag.add(ball,'GREAT_BALL',1,data),'Full ball pocket refuses new ball')
  same(before,ball,'Ball refusal immutable')
  -- Returning an old held item can need a new slot even if the new held item
  -- was removed: removing one from a 99 stack frees no physical slot.
  local mon={item='ANTIDOTE'};before=S.encode(full)
  check(Bag.giveHeld(full,mon,'POTION',data)==false and mon.item=='ANTIDOTE','Held exchange refuses without losing old item')
  same(before,full,'Failed held exchange restores new item and all slot metadata')
  local lone={inventory={POTION=1},bagOrder={'POTION'}}
  for i=1,19 do lone.inventory['EXTRA_'..i]=1;lone.bagOrder[#lone.bagOrder+1]='EXTRA_'..i end
  check(Bag.giveHeld(lone,mon,'POTION',data)=='ANTIDOTE'and mon.item=='POTION','Freed last stack allows atomic held exchange')
  check(not lone.inventory.POTION and lone.inventory.ANTIDOTE==1 and Model.consistent(lone,data),'Exchange updates both representations')
  local game={data=data,save=save};local Tx=require('src.inventory.Gen3RsShopTransaction').new(game)
  before=S.encode(save);check(Tx:canAdd(4,100),'Shop preflight supports split stacks')
  same(before,save,'Shop preflight preserves nested slot model and aggregate')
  -- Canonical direct host writes remain compatible; the stale mirror is
  -- reconciled privately and committed only on the next actual mutation.
  save.inventory.POTION=80;before=S.encode(save)
  rows=Model.rows(save,data,'ITEM');check(#rows==1 and rows[1].qty==80,'Direct host quantity writes project safely')
  same(before,save,'Direct-write projection does not repair during draw/load')
  check(not Model.consistent(save,data),'Invariant detects actual stale stored mirror')
  check(Bag.add(save,'ANTIDOTE',1,data)and Model.consistent(save,data),'Successful mutation reconciles direct host writes')
  local broken={inventory={POTION=25},bagOrder={'POTION'},gen3RsBagSlots={format=1,version=version,pockets={}}}
  before=S.encode(broken);check(Model.rows(broken,data,'ITEM')[1].qty==25,'Invalid optional mirror rebuilt from canonical goods')
  same(before,broken,'Corrupt mirror reads never write')
  check(Bag.add(broken,'POTION',1,data)and Model.consistent(broken,data),'Explicit successful mutation repairs mirror')
  for _,p in pairs(save.gen3RsBagSlots.pockets)do for _,s in ipairs(p)do check(type(s.id)=='string','Only stable IDs serialized')end end
  local unsupported={inventory={MOD_UNKNOWN=7},bagOrder={'MOD_UNKNOWN'}};before=S.encode(unsupported)
  check(not Bag.add(unsupported,'POTION',1,data),'Unsupported legacy contents never silently discarded')
  same(before,unsupported,'Unknown mod goods preserved')
end
V.set('leafgreen')
local frlg={constants={gen3Bag={pockets={ITEM=42}}},items={POTION={index=13,pocket='ITEM'}}}
local save={inventory={POTION=99},bagOrder={'POTION'}};local before=S.encode(save)
check(not Bag.add(save,'POTION',1,frlg),'FRLG retains its own stack policy')
same(before,save,'FRLG untouched by native RS model')
check(not save.gen3RsBagSlots,'Other editions never acquire RS sidecar')
print('RS_INVENTORY_CONTRACT_CHECKS',n)
