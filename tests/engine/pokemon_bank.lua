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
check(not B.convert(held,'red',data),'held items are refused for generation 1')
check(B.convert(held,'gold',data).heldItem=='BERRY','supported held item survives')
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
local store={list=function(dir) local list={};for p in pairs(remote) do list[#list+1]=p:sub(#dir+2) end;return list end,
 read=function(p) return remote[p] end,write=function(p,b) remote[p]=b;return true end}
check(B.sync(store)==1 and remote[path]==files[path],'sync uploads immutable Bank entries')
files={};check(B.sync(store)==1 and #B.list()==1,'another device can import the full Bank entry')
local prior=files[path];remote[path]='return {schema=1}'
check(not B.sync(store) and files[path]==prior,'an invalid cloud copy cannot overwrite a local entry')
print('Pokémon Bank: '..checks..' checks passed')
