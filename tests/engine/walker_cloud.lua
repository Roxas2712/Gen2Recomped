-- Two isolated device profiles, real serializer/atomic storage and slot links.
-- The remote object transport here is simulated, not a live-server claim.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer')
local filesA,filesB,remote={},{},{}
local files=filesA;local id='17';local allowed=true;local race,failWrite
local fsA,fsB
local function disk(data)
 return {read=function(p)return data[p]end,write=function(p,b)data[p]=b;return true end,
  remove=function(p)data[p]=nil;return true end,createDirectory=function()return true end,
  getInfo=function(p)return data[p]and{type='file',size=#data[p]}end}
end
fsA,fsB=disk(filesA),disk(filesB);local fs=fsA
love.filesystem=fsA
local linksA,linksB={},{};local links=linksA;local saves={}
local open=false
package.loaded['src.core.SaveData']={persistenceFs=function()return fs end,peekSlot=function(v,s)return saves[v..'/'..s]end,slotOpenElsewhere=function()return open end}
package.loaded['src.storage.AccountStorage']={storeCheck=function(store)return allowed and store.accountId==id,'Account required.'end}
package.loaded['src.cloud.RetroCloud']={accountId=function()return id end}
local function hash(b)local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return('%08x-%d'):format(h,#b)end
package.loaded['src.import.CloudSync']={hash=hash,stateKey=function()return'retro'end,loadState=function()return{links=links}end}
local W=require('src.pokewalker.Walker')
local C=require('src.pokewalker.WalkerCloud')
local store={kind='retro',accountId='17',read=function(p)if race then race()end;return remote[p]end,
 write=function(p,b)if failWrite then return nil,'Changed on another device.'end;remote[p]=b;return true end}
local n=0;local function check(v,m)assert(v,m);n=n+1 end
check(C.sync(store)=='empty'and next(remote)==nil and next(filesA)==nil,'an unused walker creates no progress or cloud objects')
local a=W.load();a.watts=123;a.minigames={day=1,daily={watts=40},games={memory={best=500,plays=3}}};a.econ={bought={gift=true}}
a.caught={{species=25,level=7}};a.stepsJournal={epoch='phone-A',total=400}
assert(W.save(a));check(C.sync(store)=='uploaded','full progress snapshot uploads through the existing object store')
local first=remote[C.PATH];local doc=assert(C.decode(first))
check(doc.state.minigames.games.memory.best==500 and doc.state.econ.bought.gift and doc.state.caught[1].species==25,'minigame records, purchases and held rewards survive encoding')
check(doc.state.stepsJournal==nil,'native sensor receipt stays on its own device')
check(C.sync(store)=='current','unchanged progress produces no new revision')
fs=fsB;files=filesB;links=linksB
check(C.sync(store,true)=='restored'and W.load().watts==123,'second device restores the same account’s complete progress')
check(W.load().minigames.games.memory.best==500 and W.load().caught[1].species==25,'second device retains the personal record and unclaimed reward')
local b=W.load();b.watts=140;assert(W.save(b));check(C.sync(store)=='uploaded','second device advances progress normally')
fs=fsA;files=filesA;links=linksA
local old=W.load();check(C.sync(store)=='restored'and W.load().watts==140,'unchanged first device pulls newer progress')
check(not W.check(old),'restoration retires the first device’s old state reference')
local active=W.load();active.watts=150;assert(W.save(active))
fs=fsB;files=filesB;links=linksB;local other=W.load();other.watts=160;assert(W.save(other));assert(C.sync(store)=='uploaded')
fs=fsA;files=filesA;links=linksA
local before=filesA[W.FILE];local good,why=C.sync(store)
check(not good and why:find('both devices',1,true)and filesA[W.FILE]==before,'concurrent offline progress blocks overwriting or adding balances')
local preserved=false;for path in pairs(filesA)do if path:find('walker/conflicts/',1,true)then preserved=true end end
check(preserved and W.load().watts==150,'conflicting remote rewards have an account-private recovery copy')
check(not C.sync(store,true)and filesA[W.FILE]==before,'login restore cannot silently discard local rewards')
remote[C.PATH]='return os.execute("do not run")'
check(not C.sync(store)and filesA[W.FILE]==before,'invalid executable remote payload never executes or replaces progress')
remote[C.PATH]=first;id='29'
check(not C.sync(store)and remote[C.PATH]==first,'another account cannot use the cloud connection')
id='17';allowed=false;check(not C.sync(store),'unconfirmed storage access is refused');allowed=true
race=function()id='29'end
check(not C.sync(store)and filesA[W.FILE]==before and not W.syncing,'account changes during HTTP reads abort and release the sync lock')
race=nil;id='17'
-- Restore a walk: local slot IDs differ; the existing cloud ID maps them.
local state=W.newState();state.walking={species=25,name='SIGN IN',raw={species='PIKACHU',level=5},source={version='red',slot='slot1',box=1,index=1}}
linksA.red={slot1={cloudId='phoneA-slot1',hash=hash('source-save')}};filesA['saves/red/slot1.lua']='source-save'
assert(W.adopt(state));filesA[C.STATE]=nil;remote[C.PATH]=nil
check(C.sync(store)=='uploaded','a walk uploads only after its source save was synchronized')
local walkRaw=remote[C.PATH]
check(C.decode(walkRaw).state.walking.source.cloudId=='phoneA-slot1','cloud references use existing save identity instead of a device-local slot')
fs=fsB;links=linksB;files=filesB;filesB[W.FILE]=nil;filesB[W.FILE..'.bak']=nil;filesB[W.FILE..'.tmp']=nil;filesB[C.STATE]=nil;W.live=nil
linksB.red={};check(not C.sync(store,true),'missing source save prevents restoration of a detached Pokémon')
linksB.red.slot8={cloudId='phoneA-slot1',hash='saved'};saves['red/slot8']={party={},boxes={}}
check(C.sync(store,true)=='restored'and W.load().walking.source.slot=='slot8','the imported source slot is resolved on the destination device')
check(W.load().walking.name=='SIGN IN','nicknames remain untouched')
W.live=nil;filesB[W.FILE]=nil;filesB[W.FILE..'.bak']=nil;filesB[W.FILE..'.tmp']=nil;filesB[C.STATE]=nil;saves['red/slot8']={boxes={{{species='PIKACHU',level=5}}}}
check(not C.sync(store,true)and not filesB[W.FILE],'a Pokémon already returned in its source save cannot also be restored onto the walker')
saves['red/slot8']={boxes={}};open=true
check(not C.sync(store,true),'an open source game blocks walker restoration');open=false
fs=fsA;links=linksA;files=filesA;W.live=nil
local current=W.load();current.watts=12;assert(W.save(current));failWrite=true
check(not C.sync(store)and not W.syncing and W.load().watts==12,'HTTP revision conflict preserves local progress and releases locks')
failWrite=false;filesA['saves/red/slot1.lua']='unsynced source'
check(not C.sync(store),'a locally changed source save must sync before the walking Pokémon can upload')
local invalid=S.decode(walkRaw);invalid.state.watts=-1
check(not C.decode(S.encode(invalid)),'negative cloud balances are rejected')
invalid=S.decode(walkRaw);invalid.state.walking.source.slot='injected'
check(not C.decode(S.encode(invalid)),'remote device-local slot injection is rejected')
fs=fsB;W.live=nil;filesB[W.FILE]='damaged';filesB[W.FILE..'.bak']=nil;filesB[W.FILE..'.tmp']=nil
check(not C.sync(store)and filesB[W.FILE]=='damaged','an unreadable local walker blocks cloud replacement and preserves the damaged bytes')
print('Pokéwalker cloud: '..n..' simulated two-device persistence checks passed')
