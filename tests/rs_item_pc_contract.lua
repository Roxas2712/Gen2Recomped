love=require('tests.love_stub');love.filesystem.load=loadfile
local S=require('src.core.SaveSerializer');local Tx=require('src.inventory.Gen3RsItemPcTransaction')
local Model=require('src.inventory.Gen3RsInventory');local Host=require('src.inventory.Bag')
local count=0
local function check(ok,why)count=count+1;assert(ok,why)end
local function same(before,save,why)check(before==S.encode(save),why)end
for _,version in ipairs({'ruby','sapphire'})do
  require('src.core.GameVersion').set(version)
  local data={constants={gen3RsBag={format=1,version=version}},items={
    POTION={index=13,pocket='ITEM',name='POTION'},ANTIDOTE={index=14,pocket='ITEM',name='ANTIDOTE'},
    POKE_BALL={index=4,pocket='BALL'},CHERI_BERRY={index=133,pocket='BERRY'},
    MACH_BIKE={index=259,pocket='KEY_ITEM',importance=1},PARCEL={index=349,pocket='KEY_ITEM',importance=2},
  }}
  for i=1,55 do data.items['EXTRA_'..i]={index=400+i,pocket='ITEM',name='EXTRA '..i}end
  local game={data=data,save={inventory={POTION=100},bagOrder={'POTION'},
    pcItems={POTION=998,ANTIDOTE=4},pcOrder={'ANTIDOTE','POTION'},player={name='QA'}}}
  local save=game.save;local inv,order,pc,pcOrder=save.inventory,save.bagOrder,save.pcItems,save.pcOrder
  local before=S.encode(save);local tx=Tx.new(game)
  check(tx.valid and tx.store.items[1].id==14,'PC snapshot preserves host order and uses private numeric views')
  same(before,save,'Opening item PC writes no save fields')
  local rows=Model.rows(save,data,'ITEM')
  check(tx:deposit(rows[2].slot,1),'Deposit selected second ordinary stack')
  check(save.inventory.POTION==99 and save.pcItems.POTION==999,'Exactly one moves to PC')
  check(Model.consistent(save,data),'Deposit retains physical aggregate invariant')
  check(save.inventory==inv and save.bagOrder==order and save.pcItems==pc and save.pcOrder==pcOrder,'All authoritative table identities retained')
  rows=Model.rows(save,data,'ITEM');before=S.encode(save)
  check(not tx:deposit(rows[1].slot,1),'PC stack refuses above 999')
  same(before,save,'Overflow loses neither bag nor PC goods')
  check(tx:canWithdraw(13,201),'Withdraw can allocate multiple ordinary stacks')
  same(before,save,'Capacity preflight preserves all save bytes')
  check(tx:withdraw(13,201),'Multi-stack withdrawal committed')
  check(save.pcItems.POTION==798 and save.inventory.POTION==300,'Withdrawal conserves quantity')
  rows=Model.rows(save,data,'ITEM')
  check(#rows==4 and rows[1].qty==99 and rows[4].qty==3,'Four physical bag rows after withdrawal')
  check(Model.consistent(save,data),'Withdrawal aggregate invariant')
  before=S.encode(save)
  check(not tx:withdraw(13,799),'Cannot withdraw more than PC owns')
  check(not tx:deposit({id='POTION',pocket='ITEMS',index=1},100),'Cannot borrow quantity from another bag stack')
  same(before,save,'Invalid quantities leave both stores unchanged')
  save.inventory={POTION=99*20};save.bagOrder={'POTION'};save.gen3RsBagSlots=nil
  before=S.encode(save);check(not tx:canWithdraw(14,1)and not tx:withdraw(14,1),'Full physical bag refuses withdrawal')
  same(before,save,'Full bag never debits PC')
  save.inventory={CHERI_BERRY=999};save.bagOrder={'CHERI_BERRY'};save.gen3RsBagSlots=nil
  check(tx:deposit(Model.rows(save,data,'BERRY')[1].slot,999),'999 berries move atomically to PC')
  check(not save.inventory.CHERI_BERRY and save.pcItems.CHERI_BERRY==999,'Full berry amount conserved')
  save.inventory={MACH_BIKE=1,PARCEL=1};save.bagOrder={'MACH_BIKE','PARCEL'};save.gen3RsBagSlots=nil
  rows=Model.rows(save,data,'KEY_ITEM')
  before=S.encode(save);check(not tx:deposit(rows[2].slot,1),'Original importance-two deposit refusal')
  same(before,save,'Refused important parcel remains in bag')
  check(tx:deposit(rows[1].slot,1),'Original importance-one key deposit is permitted')
  check(save.pcItems.MACH_BIKE==1,'Deposited key retained')
  before=S.encode(save);check(not tx:toss(259,1),'PC TOSS protects importance-one key')
  same(before,save,'Protected key preserved')
  check(tx:toss(14,3)and save.pcItems.ANTIDOTE==1,'PC TOSS removes only chosen quantity')
  tx:refresh();local first,last=tx.store.items[1],tx.store.items[#tx.store.items]
  tx.store.items[1],tx.store.items[#tx.store.items]=last,first
  local goods=S.encode(save.pcItems)
  check(tx:reorder()and save.pcOrder[1]==tx:id(last.id),'PC SELECT order commits stable IDs')
  check(goods==S.encode(save.pcItems),'Reorder preserves goods')
  tx.store.items[1].qty=9999;before=S.encode(save)
  check(not tx:reorder(),'Stale altered PC view cannot overwrite host quantities')
  same(before,save,'Stale PC view refusal atomic')
  local full={};for i=1,50 do full['EXTRA_'..i]=1 end
  save.pcItems=full;save.pcOrder={};save.inventory={POTION=1};save.bagOrder={'POTION'};save.gen3RsBagSlots=nil
  tx:refresh();before=S.encode(save)
  check(not tx:deposit(Model.rows(save,data,'ITEM')[1].slot,1),'Fifty occupied PC slots refuse a new item')
  same(before,save,'Full PC refusal keeps bag and all fifty goods')
  save.inventory={EXTRA_1=1};save.bagOrder={'EXTRA_1'}
  check(tx:deposit(Model.rows(save,data,'ITEM')[1].slot,1)and save.pcItems.EXTRA_1==2,'Full PC can top up an existing stack')
  -- Controller timing and original move semantics are independent of render.
  local list={{id=13,qty=37},{id=14,qty=2},{id=4,qty=1}}
  local close=0;local load=require('compat.gen1-rs.Loader').new(version,{
    ['src.ui.game3.window']={template=function(...)return{...}end},
    ['src.ui.game3.frlg_font']={},['src.core.game3.rom_text']={plain=function(k)return k end},
    ['src.core.game3.storage']={ensure=function()return{items=list}end},
    ['src.core.game3.items_data']={displayName=function(id)return tostring(id)end,description=function()return''end,
      info=function()return{importance=0}end},
    ['src.core.game3.bag']={canAdd=function()return false end},
    ['src.core.game3.profile']={forSession=function()return{id=version}end},
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
    ['src.core.game3.se_ids']={SE_SELECT=5},['src.core.game3.audio']={playSe=function()end},
  })
  local ui=load('src.ui.game3.rse.item_storage')
  local function press(k)ui.handleInput({wasPressed=function(_,key)return key==k end,isDown=function()return false end})end
  ui.show({session={},onClose=function()close=close+1 end})
  press('a');check(ui.state=='quantity'and ui.quantity==1,'Native withdraw quantity opens at one')
  press('down');check(ui.quantity==37,'Native quantity wraps down to maximum')
  press('up');press('right');check(ui.quantity==11,'Native right adds ten')
  press('left');check(ui.quantity==1,'Native left subtracts ten')
  press('b');check(ui.state=='list','Quantity B returns to list')
  press('select');press('down');press('down');press('b')
  check(ui.state=='list'and list[1].id==13 and list[2].id==14,'Pinned controller B cancels SELECT move')
  press('up');press('select');press('down');press('down');press('select')
  check(ui.state=='list'and list[1].id==14 and list[2].id==13,'SELECT confirms native insertion order')
  press('b');check(close==1 and not ui.open,'Native close callback fires once')
  ui.close();check(close==1,'Repeated close does not resume twice')
  local policy=require('compat.gen1-rs.Loader').new(version)('src.ui.game3.rs.player_pc_policy')
  local text={}
  for key,symbol in pairs(policy.aliases)do text[key]={};text[symbol]={}end
  for _,key in ipairs({'gOtherText_Exit','gOtherText_HowManyToDeposit','gOtherText_CantStoreSomeoneItem',
    'gOtherText_NoRoomForItems','gOtherText_DepositedItems'})do text[key]={}end
  for i=0,3 do text[policy.storageDescriptions..':'..i]={}end
  data.constants.gen3RsItemPc={format=1,version=version,textIR=text}
  local Screen=require('src.ui.Gen3RsPlayerPC')
  check(Screen.available(game),'Current native PC metadata and valid fifty-slot state accepted')
  save.pcItems.EXTRA_1=1000;before=S.encode(save)
  check(not Screen.available(game),'Overfilled old PC remains on legacy recovery menu')
  same(before,save,'Native availability never truncates malformed legacy goods')
  save.pcItems.EXTRA_1=2;data.constants.gen3RsItemPc.version=version=='ruby'and'sapphire'or'ruby'
  check(not Screen.available(game),'Mixed-edition PC text rejected')
  data.constants.gen3RsItemPc.version=version
  local savedLove=love;love=nil
  package.loaded['compat.gen1-rs.reference.src.ui.game3.rs.player_pc_policy']=nil
  local headless=require('src.import.Gen3RsItemPcAssets').valid(data.constants.gen3RsItemPc,version)
  love=savedLove;check(headless,'Cache metadata validates without LÖVE or a live native session')
  save.flags={};before=S.encode(save)
  local roots=Screen.rootRows(game)
  check(#roots==3 and roots[1].id=='storage'and roots[2].id=='player'and roots[3].id=='quit',
    'RS root has storage/player/logoff with no FRLG professor row')
  same(before,save,'Reading native root flags never repairs or edits saves')
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(version))
  save.flags[('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_GAME_CLEAR'))]=true
  save.flags[('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_PC_LANETTE'))]=true
  roots=Screen.rootRows(game)
  check(#roots==4 and roots[3].id=='hall'and roots[4].id=='quit','Original RS clear/Lanette flags gate the late root')
end
print('RS_ITEM_PC_CONTRACT_CHECKS',count)
