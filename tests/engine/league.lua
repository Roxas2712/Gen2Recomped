package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local files={};local fs={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
 getInfo=function(p) return files[p] and {size=#files[p]} end,createDirectory=function() return true end,remove=function(p) files[p]=nil;return true end,
 getDirectoryItems=function(path) local r={};for p in pairs(files) do local n=p:match('^'..path:gsub('(%W)','%%%1')..'/([^/]+)$');if n then r[#r+1]=n end end;return r end}
love.filesystem=fs
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8) end,encode=function(_,_,b) return b end}
local permitted=true
package.loaded['src.storage.AccountStorage']={check=function() return permitted,'Account required.' end}
package.loaded['src.core.SaveData']={persistenceFs=function() return fs end}
local S=require('src.core.SaveSerializer');local B=require('src.storage.PokemonBank');local E=require('src.storage.LeagueEgg')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local function egg(dex)
 return {schema=1,source={version='bank',slot='league',place='League reward'},origin={version='bank',recordId=string.rep('a',64),kind='retrorecomp_league',pool='league-eggs-v1',generation=9,shiny=true,isEgg=true,seed=string.rep('1',64)},mon={species='DEX_'..dex,level=1,moves={},ot='RetroRecomp',otId=2712,isEgg=true,eggSteps=5120},canonical={dex=dex,moves={}}}
end
local raw=egg(1025);local bytes=S.encode(raw);local digest=love.data.hash('sha256',bytes)
check(B.decode(bytes,digest),'the Bank retains a national species independently from supported cartridges')
local id=assert(E.keep({kind='league_egg',entry=bytes,digest=digest}));check(E.keep({kind='league_egg',entry=bytes,digest=digest})==id,'restoring a reward on the same device keeps one identity')
check(not B.convert(raw,'emerald',{pokemon={},moves={},items={},constants={}}),'an unsupported species remains in the Bank without a fabricated native monster')
check(not E.universal({origin=raw.origin,canonical=raw.canonical}),'a malformed universal receipt cannot dereference missing source or monster data')
check(not B.decode(bytes..' garbage',digest),'tampered reward bytes are rejected')
local def={dex=25,baseStats={hp=35,attack=55,defense=30,speed=90,special=50},growthRate='MEDIUM_FAST',level1Moves={'THUNDERSHOCK'},learnset={},catchRate=190,eggCycles=10}
local data={pokemon={PIKACHU=def},moves={THUNDERSHOCK={pp=30,name='THUNDERSHOCK'}},items={},constants={}}
local e=egg(25);local original=S.encode(e)
check(not B.convert(e,'red',data),'Generation 1 cannot receive a league egg')
local mon=assert(B.convert(e,'crystal',data))
check(mon.species=='PIKACHU' and mon.level==5 and mon.eggSteps==2560 and mon.shiny and mon.dvs.special==10,'Gen 2 materializes a native shiny egg with native hatch steps and DVs')
def.baseStats.spatk=50;def.baseStats.spdef=40;def.evYield={};def.abilities={'STATIC'}
local g3=assert(B.convert(e,'emerald',data));local again=assert(B.convert(e,'emerald',data))
check(g3.eggSteps>0 and g3.level==5 and require('src.pokemon.Stats').isShinyGen3(g3.personality,g3.otId),'Gen 3 materializes the immutable shiny claim as actual shiny genetics')
check(S.encode(g3)==S.encode(again) and S.encode(e)==original,'native materialization is deterministic and does not mutate the universal egg')
permitted=false;check(not E.keep({kind='league_egg',entry=bytes,digest=digest}),'league storage requires the account policy')
local Proof=require('src.link.ArenaProof')
check(Proof.same({winner=1,turns=4},{turns=4,winner=1}) and not Proof.same({hp=1},{hp=2}),'result state comparison is independent of JSON key order and detects state changes')
print('League rewards and proof: '..n..' checks passed')

local account,signed='1',true;local calls=0;local fail=true;local clock=100
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end,accountId=function() return account end}
package.loaded['src.cloud.Task']={new=function(fn) return {cancel=function() end,poll=function() local a,b=fn();return {kind='done',first=a,second=b} end} end}
package.loaded['src.cloud.Tournaments']={request=function() calls=calls+1;if fail then return nil,'Offline' end;return {account_id=account,battle={state='ready'}} end}
local time=os.time;os.time=function() return clock end
local Out=require('src.link.ArenaResults');local bid='11111111-1111-4111-8111-111111111111'
assert(Out.keep(bid,bid,{battle=bid,ticket=string.rep('a',64),turns=4,digest=string.rep('a',64),status='complete',winner=1}))
Out.pump();Out.pump();check(calls==1 and files[Out.DIRECTORY..'/'..bid..'.lua'],'an offline result remains durable for a later retry')
clock=120;account='2';Out.pump();check(calls==1,'another account never sends the previous account result')
account='1';fail=false;Out.pump();Out.pump();check(calls==2 and not files[Out.DIRECTORY..'/'..bid..'.lua'],'an acknowledged retry removes only its own completed outbox entry')
os.time=time
print('Arena result outbox: 3 checks passed')
