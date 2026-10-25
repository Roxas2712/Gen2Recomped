package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0
local function check(value,why) assert(value,why);checks=checks+1 end
local files={}
local disk={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
  createDirectory=function() return true end,remove=function(p) files[p]=nil;return true end,
  getInfo=function(p) return files[p] and {size=#files[p]} end,
  getDirectoryItems=function(dir) local rows={};for path in pairs(files) do local n=path:match('^'..dir..'/([^/]+)$');if n then rows[#rows+1]=n end end;return rows end}
-- Fingerprint seam: deterministic fake, not a test of LOVE's SHA-256 primitive.
love.data={hash=function(_,bytes) local h=5381;for i=1,#bytes do h=(h*33+bytes:byte(i))%4294967296 end;return string.rep(string.format('%08x',h),8) end,
  encode=function(_,_,value) return value end}
local writes,created=0,0
local Saves={persistenceFs=function() return disk end,slotOpenElsewhere=function() return false end,
  createSlot=function() created=created+1;return 'slot'..created end,
  writeSlot=function(v,id,save) writes=writes+1;SavesWritten=save;return true end,
  renameSlot=function() return true end}
package.loaded['src.core.SaveData']=Saves
local B=require('src.storage.PokemonBank')
local S=require('src.core.SaveSerializer')
local base={hp=45,attack=49,defense=49,speed=45,special=65}
local data={pokemon={BULBASAUR={dex=1,baseStats=base}},moves={TACKLE={name='TACKLE',pp=35}},items={BERRY={name='BERRY'}},constants={}}
local mon={species='BULBASAUR',nickname='Buddy',level=12,moves={{id='TACKLE',pp=20}},dvs={hp=15,attack=15,defense=15,speed=15,special=15},statExp={hp=400},hp=25,ot={name='Original'},shiny=false}
local original=S.encode(mon)
local id=assert(B.deposit(mon,'red','slot1','Party 1',data))
check(S.encode(mon)==original,'deposit never mutates the source Pokémon')
check(#B.list()==1 and B.list()[1].mon.ot.name=='Original','the original full record survives the Bank round trip')
check(B.deposit(mon,'red','slot1','Party 1',data)==id and #B.list()==1,'depositing the same unchanged location is idempotent')
local path=B.DIRECTORY..'/'..id..'.lua'
check(not B.decode(files[path]:gsub('Buddy','Other'),id),'fingerprint mismatch refuses a changed remote record')
check(not B.decode('return (function() _G.BANK_EXECUTED=true end)()',id) and not _G.BANK_EXECUTED,'network Bank files are parsed, never evaluated')
local entry=B.list()[1]
local copy=assert(B.convert(entry,'gold',data))
check(copy~=mon and copy.species=='BULBASAUR' and copy.dvs.attack==15 and copy.ot.name=='Original','same-model copies preserve identity and genetics')
check(S.encode(entry.mon)==original,'conversion never alters the immutable Bank original')
local bad={pokemon={},moves=data.moves,items={},constants={}}
check(not B.convert(entry,'gold',bad),'unknown target species is refused')
bad={pokemon=data.pokemon,moves={},items={},constants={}}
check(not B.convert(entry,'gold',bad),'unknown target moves are refused rather than removed')
local held=S.decode(S.encode(entry));held.mon.heldItem='BERRY';held.canonical.item='BERRY'
local parked=assert(B.convert(held,'red',data))
check(not parked.heldItem and parked.retroBankHeld.item=='BERRY','unsupported held items are staged for custody while Gen1 receives a compatible Pokémon')
check(B.convert(held,'gold',data).item=='BERRY','legacy held-item input converts to the native item field')
local Items=require('src.storage.BankItems')
local fail=Items.transaction({version='red',party={parked}},function() return nil,'injected save failure' end)
check(not fail and #Items.list()==0,'a failed save rolls item custody back without consuming the original')
check(Items.transaction({version='red',party={parked}},function() return 'new-copy' end) and #Items.list()==1,'committing a Gen1 copy keeps its held item in the Item Bank')
local returnEntry=B.makeEntry(parked,'red','slot2','Party 1',data)
local returning=assert(B.convert(returnEntry,'gold',data))
check(returning.item=='BERRY' and not returning.heldItem and returning.retroBankItem,'the associated item is restored in the native field when the Pokémon returns to a supported game')
check(Items.transaction({version='gold',party={returning}},function() return 'returned-copy' end),'restoring an item commits its custody assignment with the destination save')
check(Items.list()[1].state=='assigned','a restored held item cannot also be assigned from available storage')
assert(Items.transaction({version='red',party={parked}},function() return 'parked-again' end))
local otherEntry=B.makeEntry(mon,'gold','slot9','Party 2',data)
local oldData=B.data;B.data=function() return data end
local equipped=assert(Items.equip(Items.list()[1].id,otherEntry));B.data=oldData
check(equipped and Items.list()[1].assignedTo==otherEntry.origin.recordId,'a stored item can be attached to a different Bank Pokémon')
local withoutItem=assert(B.convert(returnEntry,'gold',data))
check(not withoutItem.item and not withoutItem.heldItem and not withoutItem.retroBankHeld,'the original Pokémon can return without stealing an item assigned to another monster')
local beforeItems=files[Items.FILE]
local fake={read=function() return 'not a valid item bank' end,write=function() error('invalid remote data must not be overwritten') end}
check(not Items.sync(fake) and files[Items.FILE]==beforeItems,'invalid remote item records never replace either side')
local Dex=require('src.storage.GlobalPokedex')
local pokedex=assert(Dex.collect({},B.list()))
check(pokedex.species[1].owned and pokedex.species[1].sources['red:slot1'],'the global Pokédex registers Bank species with their source game and save slot')
local merged=Dex.merge(pokedex,{schema=1,species={[2]={owned=true,sources={['gold:slot2']={version='gold',slot='slot2'}}}}})
check(merged.species[1].owned and merged.species[2].owned,'global Pokédex merging preserves discoveries from both devices')
local form=S.decode(S.encode(entry));form.mon.form=1
check(not B.convert(form,'gold',data),'unsupported cross-game forms are refused')
local modern={pokemon={BULBASAUR={dex=1,baseStats={hp=45,attack=49,defense=49,speed=45,spatk=65,spdef=65},evYield={},abilities={'OVERGROW'}}},moves=data.moves,items=data.items,constants={natureOrder={'HARDY'}}}
check(not B.convert(entry,'emerald',modern),'IV/DV adaptation requires explicit consent')
local up,note=B.convert(entry,'emerald',modern,true)
check(up.ivs.attack==31 and up.ivs.spdef==31 and up.evs.hp==20 and up.nature=='HARDY' and note,'up-conversion uses bounded IVs and destination nature')
local total=0;for _,v in pairs(up.evs) do total=total+v end;check(total<=510,'EV conversion respects the destination total')
local upgraded={mon=up,canonical=entry.canonical,source={version='emerald'}}
local down=assert(B.convert(upgraded,'gold',data,true))
check(down.ivs==nil and down.dvs.attack==15 and down.dvs.hp==15 and down.personality==nil,'down-conversion produces valid classic genetics')
local sparse={party={[3]=mon},boxes={[1]={[20]=mon},[2]={mons={[7]=mon}}}}
check(#B.scan(sparse,'gold')==3,'party and box scans preserve sparse occupied slots')
local target={party={mon},boxes={[1]={[1]=mon,[3]=mon}},player={name='Test'}}
local before=S.encode(target)
B.readSave=function() return target end
local destination=assert(B.deliver({entry},'gold','base-slot',false,data))
check(destination=='slot1' and writes==1 and created==1,'delivery writes exactly one new slot')
check(S.encode(target)==before and SavesWritten.boxes[1][2].nickname=='Buddy','delivery fills the first empty PC cell in a clone')
check(SavesWritten.party[1].nickname=='Buddy' and SavesWritten.boxes[1][3].nickname=='Buddy','existing party and PC occupants are preserved')
check(not B.deliver({entry},'gold','base-slot',false,bad) and writes==1 and created==1,'failed compatibility cannot create or write a save')
Saves.slotOpenElsewhere=function() return true end
check(not B.deliver({entry},'gold','base-slot',false,data) and writes==1,'an open save cannot be copied while being played')
Saves.slotOpenElsewhere=function() return false end
local remote={}
local store={list=function(dir) local list={};for p in pairs(remote) do local name=p:match('^'..dir..'/([^/]+)$');if name then list[#list+1]=name end end;return list end,
 read=function(p) return remote[p] end,write=function(p,b) remote[p]=b;return true end}
local bankCount=#B.list()
check(bankCount==2 and B.sync(store)==bankCount and remote[path]==files[path],'sync uploads both original and item-equipped immutable Bank entries')
files={};check(B.sync(store)==bankCount and #B.list()==bankCount,'another device can import every full Bank entry')
local prior=files[path];remote[path]='return {schema=1}'
check(not B.sync(store) and files[path]==prior,'an invalid cloud copy cannot overwrite a local entry')
local native=S.decode(S.encode(mon))
native.item='BERRY';native.ot='Original';native.otId=2712
native.kasc={moveMemory={'TACKLE'},legacy={edition='gold',serial=7}}
local nativeEntry=B.makeEntry(native,'gold','native-slot','Party 1',data)
check(nativeEntry.source.trainerId==2712 and nativeEntry.canonical.item=='BERRY','native OT IDs and held-item identities are collected without treating OT names as tables')
local gen1=assert(B.convert(nativeEntry,'red',data))
check(not gen1.item and not gen1.heldItem and gen1.retroBankHeld.item=='BERRY','a native carried item is parked before entering Gen1')
check(Items.transaction({version='red',party={gen1}},function() return 'native-copy' end),'native-item custody commits with its save copy')
local roundtrip=assert(B.convert(B.makeEntry(gen1,'red','native-copy','Party 1',data),'gold',data))
check(roundtrip.item=='BERRY' and not roundtrip.heldItem and roundtrip.otId==2712,'returning native Pokémon regain their associated item and trainer identity')
check(S.encode(roundtrip.kasc)==S.encode(native.kasc) and native.item=='BERRY','unrecognized mod Lua fields survive both conversions without changing the source')
local conflict=S.decode(S.encode(nativeEntry));conflict.mon.heldItem='OTHER'
check(not B.convert(conflict,'gold',data),'conflicting item aliases require explicit resolution')
print('Pokémon Bank: '..checks..' checks passed')
