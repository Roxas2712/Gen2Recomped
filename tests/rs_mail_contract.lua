love=require('tests.love_stub');love.filesystem.load=loadfile
local S=require('src.core.SaveSerializer');local Mail=require('src.inventory.Gen3RsMail')
local Inventory=require('src.inventory.Gen3RsInventory');local count=0
local function check(ok,why)count=count+1;assert(ok,why)end
local function same(bytes,save,why)check(bytes==S.encode(save),why)end
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local words={0,1,512,513,1024,65535,65535,65535,65535}
for _,version in ipairs({'ruby','sapphire'})do
  require('src.core.GameVersion').set(version)
  local data={constants={gen3RsBag={format=1,version=version}},items={
    ORANGE_MAIL={index=121,pocket='ITEM',mail=true},HARBOR_MAIL={index=122,pocket='ITEM',mail=true},
    POTION={index=13,pocket='ITEM'},ANTIDOTE={index=14,pocket='ITEM'},
  },pokemon={TREECKO={index=277},UNOWN={index=201},PIKACHU={index=25}}}
  local save={version=version,inventory={ORANGE_MAIL=100,HARBOR_MAIL=1},bagOrder={'ORANGE_MAIL','HARBOR_MAIL'},
    player={name='QA',id=4660,secretId=22136},party={{species='TREECKO',item='POTION',hp=17,exp=135},
      {species='UNOWN',personality=0x03020100,hp=23}}}
  local game={data=data,save=save};local before=S.encode(save);local m=Mail.new(game)
  check(m.valid and #m:mailbox()==0,'Old zero-mail save projects as original empty mailbox')
  same(before,save,'Opening/reading empty mailbox never initializes a save pool')
  check(require('src.inventory.Bag').giveHeld(save,save.party[2],'ORANGE_MAIL',data)==false,
    'Bare held-item API cannot attach uncomposed RS stationery')
  same(before,save,'Bare stationery refusal preserves bag and mon')
  check(m:isMail('ORANGE_MAIL')and not m:isMail('POTION'),'Original twelve-mail item policy')
  local rows=Inventory.rows(save,data,'ITEM');local tx=assert(m:prepareGive(1,'ORANGE_MAIL',rows[2].slot))
  check(tx.previous=='POTION'and tx.record.itemId==121,'Prepared give uses exact selected native stack')
  check(tx.record.trainerId==0x56781234 and tx.record.playerName=='QA','Original sender ID includes secret ID')
  same(before,save,'Composer receipt leaves item, previous held item and mail unchanged')
  check(m:cancel(tx),'Composer cancel accepted once');check(not m:cancel(tx),'Composer cancel idempotent')
  same(before,save,'Cancel restores exact physical bag ordering by never committing a draft')
  tx=assert(m:prepareGive(1,'ORANGE_MAIL',rows[2].slot))
  local inv,order,party,mon=save.inventory,save.bagOrder,save.party,save.party[1]
  check(not m:accept(tx,{1,2,3}),'Incomplete word list refused');same(before,save,'Invalid words preserve all save bytes')
  check(m:accept(tx,words),'Composed mail commits atomically')
  check(save.inventory.ORANGE_MAIL==99 and save.inventory.POTION==1 and mon.item=='ORANGE_MAIL'and mon.mail==0,
    'New letter, previous held item and selected bag quantity conserved')
  check(save.inventory==inv and save.bagOrder==order and save.party==party and save.party[1]==mon,
    'Authoritative inventory/party/mon table identities retained')
  check(save.gen3RsMail.records[1].item=='ORANGE_MAIL'and save.gen3RsMail.records[1].species=='TREECKO',
    'Canonical mail pool persists stable item/species IDs')
  rows=Inventory.rows(save,data,'ITEM')
  check(rows[1].id=='ORANGE_MAIL'and rows[1].qty==99 and rows[2].id=='HARBOR_MAIL',
    'Only selected second mail stack consumed; original first stack unchanged')
  before=S.encode(save);local read=m:readParty(1);read.words[1]=600
  check(m:readParty(1).words[1]==0,'Readers receive independent immutable record copies')
  same(before,save,'Reading mail changes no save bytes')
  local taken,takeWhy=require('src.inventory.Bag').takeHeld(save,mon,data)
  check(not taken and takeWhy=='mail','Bare TAKE cannot erase an authored letter')
  check(require('src.inventory.Bag').giveHeld(save,mon,'HARBOR_MAIL',data)==false,
    'Bare GIVE cannot overwrite authored held mail')
  same(before,save,'Bare held-item APIs preserve complete authored message')
  check(not m:accept(tx,words),'Accepted receipt cannot debit again')
  local rejected,why=m:prepareGive(1,'HARBOR_MAIL')
  check(not rejected and why=='holding_mail','Existing mail cannot be overwritten by item swap')
  same(before,save,'Rejected mail swap keeps message and item')
  check(m:store(1),'Held letter sent to mailbox')
  check(not mon.item and not mon.mail and #m:mailbox()==1 and m:mailbox()[1].id==6,
    'Original first mailbox slot starts at native slot six')
  check(m:mailbox()[1].record.words[3]==512,'Mailbox retains authored message')
  local pool=save.gen3RsMail.records
  check(m:giveFromMailbox(6,2),'Existing mailbox message given to second party mon')
  check(save.party[2].item=='ORANGE_MAIL'and save.party[2].mail==0 and #m:mailbox()==0,
    'Mailbox GIVE transfers same message into a free held slot')
  check(save.gen3RsMail.records==pool,'Canonical mail records table identity retained')
  check(m:readParty(2).playerName=='QA'and m:readParty(2).words[3]==512,'Mailbox GIVE retains original author/words')
  check(m:take(2),'Explicit discard returns stationery to bag')
  check(save.inventory.ORANGE_MAIL==100 and not save.party[2].item and #m:mailbox()==0,
    'Discard returns exactly one original stationery')
  -- A newly composed Unown letter has the original encoded form; reload maps
  -- it back through stable UNOWN plus form without changing the sender's form.
  tx=assert(m:prepareGive(2,'HARBOR_MAIL'));check(m:accept(tx,words),'Unown letter accepted')
  local native=m:readParty(2);check(native.species>=30000 and native.species<30028,'Original Unown personality form encoded')
  local form=native.species;check(m:store(2),'Unown letter stored')
  local disk=S.encode(save);local reloaded=assert(S.decode(disk));local rm=Mail.new({data=data,save=reloaded})
  check(rm.valid and rm:mailbox()[1].record.species==form,'Serialized save reload preserves message, sender and Unown form')
  same(disk,reloaded,'Reload projection leaves serialized state unchanged')
  check(m:moveToBag(6),'Mailbox MOVE TO BAG commits')
  check(save.inventory.HARBOR_MAIL==1 and #m:mailbox()==0,'MOVE TO BAG returns design once and erases message')
  before=S.encode(save);check(not m:moveToBag(6),'Empty mail slot cannot duplicate stationery');same(before,save,'Repeated mailbox transfer is inert')
  tx=assert(m:prepareGive(2,'HARBOR_MAIL'));local oldMon=save.party[2];save.party[2]=clone(oldMon)
  before=S.encode(save);local swapped,swapReason=m:accept(tx,words)
  check(not swapped and swapReason=='stale','Replacing selected mon invalidates its outstanding receipt')
  same(before,save,'Replaced identical mon cannot inherit another mon draft')
  -- Filling the bag after composing/while a picker is open invalidates the
  -- receipt rather than overwriting newly received goods.
  tx=assert(m:prepareGive(2,'HARBOR_MAIL'));save.inventory.ANTIDOTE=1
  before=S.encode(save);local ok,reason=m:accept(tx,words)
  check(not ok and reason=='stale','Stale composer receipt refused');same(before,save,'Stale refusal preserves external goods and current mail')
  tx=assert(m:prepareGive(2,'HARBOR_MAIL'));check(m:accept(tx,words),'Fresh composer receipt remains usable')
  local held=clone(save.gen3RsMail.records[1])
  for slot=7,16 do save.gen3RsMail.records[slot]=clone(held)end
  before=S.encode(save);ok,reason=m:store(2)
  check(not ok and reason=='mailbox_full','Ten mailbox slots refuse an eleventh letter')
  same(before,save,'Full mailbox preserves held letter and every existing message')
  save.party[1].item='POTION';before=S.encode(save)
  ok,reason=m:giveFromMailbox(6,1);check(not ok and reason=='holding_item','Mailbox GIVE refuses occupied held slot')
  same(before,save,'GIVE refusal loses neither existing held item nor mailbox letter')
  -- Twenty occupied physical ordinary slots leave room for neither a discarded
  -- held stationery nor a mailbox transfer. Preflights cannot erase the text.
  save.inventory={POTION=99*20};save.bagOrder={'POTION'};save.gen3RsBagSlots=nil
  before=S.encode(save);ok,reason=m:take(2)
  check(not ok and reason=='bag_full','Full physical bag refuses TAKE');same(before,save,'TAKE refusal preserves complete letter')
  ok,reason=m:moveToBag(6);check(not ok and reason=='bag_full','Full bag refuses MOVE TO BAG')
  same(before,save,'Mailbox full-bag refusal preserves all messages')
  save.party[1].item=nil;save.inventory={ORANGE_MAIL=1};save.bagOrder={'ORANGE_MAIL'}
  save.gen3RsBagSlots=nil;save.party[1].isEgg=true;before=S.encode(save)
  check(not m:prepareGive(1,'ORANGE_MAIL'),'Egg cannot receive newly composed mail')
  check(not m:giveFromMailbox(6,1),'Egg cannot receive mailbox mail');same(before,save,'Egg refusal has no effects')
  save.party[1].isEgg=nil
  local savedPool=clone(save.gen3RsMail)
  save.gen3RsMail.records[7].words[1]=65536;before=S.encode(save)
  local malformed=Mail.new(game);check(not malformed.valid and malformed.reason=='invalid_record','Malformed legacy words fail closed')
  check(not malformed:store(2),'Malformed mailbox cannot be truncated during transfer')
  same(before,save,'Malformed records retained unchanged')
  save.gen3RsMail=savedPool;save.gen3RsMail.version=version=='ruby'and'sapphire'or'ruby';before=S.encode(save)
  check(not Mail.new(game).valid,'Mixed-edition persisted pool rejected');same(before,save,'Mixed pool retained untouched')
  save.gen3RsMail=savedPool;save.party[2].mail=4;before=S.encode(save)
  check(not Mail.new(game).valid,'Dangling held-mail reference rejected');same(before,save,'Dangling letter not silently deleted')
  data.constants.gen3RsBag.version='emerald';before=S.encode(save)
  check(not Mail.new(game).valid,'Other editions do not acquire RS mail semantics');same(before,save,'Non-RS save untouched')
  check(not Mail.new(game):mailbox(),'Non-RS mailbox API fails closed without loading mail policy')
end
for _,version in ipairs({'ruby','sapphire'})do
  local Bag=require('src.inventory.Bag')
  local data={constants={gen3RsBag={format=1,version=version}},items={ORANGE_MAIL={index=121,pocket='ITEM'},POTION={index=13,pocket='ITEM'}}}
  local save={inventory={},party={{item='ORANGE_MAIL'}},player={}};local mon=save.party[1]
  check(Bag.takeHeld(save,mon,data)=='ORANGE_MAIL'and save.inventory.ORANGE_MAIL==1 and not mon.item,
    'Explicit TAKE recovers old uncomposed stationery without inventing a letter')
  check(save.gen3RsMail==nil,'Legacy recovery initializes no empty mail pool')
  mon.item='ORANGE_MAIL';save.inventory={POTION=1980};save.bagOrder={'POTION'};save.gen3RsBagSlots=nil
  local before=S.encode(save);local got,why=Bag.takeHeld(save,mon,data)
  check(not got and why=='full','Legacy recovery observes original physical bag capacity');same(before,save,'Full-bag recovery keeps legacy held stationery')
  save.inventory={};save.bagOrder={};mon.mail=0;save.gen3RsMail={format=1,version=version,records={[1]={words={42},item='ORANGE_MAIL'}}}
  before=S.encode(save);got,why=Bag.takeHeld(save,mon,data)
  check(not got and why=='mail','Malformed existing authored record is never treated as blank legacy stationery')
  same(before,save,'Recovery cannot erase unknown legacy letter bytes')
end
print('PASS_RS_MAIL_CONTRACT '..count)
