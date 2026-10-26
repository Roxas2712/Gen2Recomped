package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local files={};local fs={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
 getInfo=function(p) return files[p] and {size=#files[p]} end,createDirectory=function() return true end,remove=function(p) files[p]=nil;return true end}
love.filesystem=fs
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8) end,encode=function(_,_,b) return b end}
local permitted=true
package.loaded['src.storage.AccountStorage']={check=function() return permitted,'Account required.' end}
package.loaded['src.core.SaveData']={persistenceFs=function() return fs end}
local S=require('src.core.SaveSerializer');local B=require('src.storage.PokemonBank');local G=require('src.cloud.GiftCodes');local R=require('src.storage.GiftReward')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local entry={schema=1,source={version='red',slot='gift',place='Gift code'},
 origin={recordId=string.rep('a',64),kind='retrorecomp_gift',pool='native-gifts-v1',generation=1,shiny=false,isEgg=false,seed=string.rep('1',64)},
 mon={species='DEX_25',level=5,moves={},ot='RetroRecomp',otId=2712},canonical={dex=25,moves={{name='FLY'}}}}
local def={dex=25,baseStats={hp=35,attack=55,defense=30,speed=90,special=50},growthRate='MEDIUM_FAST',
 level1Moves={'THUNDERSHOCK'},learnset={},catchRate=190,eggCycles=10}
local data={pokemon={PIKACHU=def},moves={THUNDERSHOCK={pp=30,name='THUNDERSHOCK'},FLY={pp=15,name='FLY'}},items={},constants={}}
local original=S.encode(entry)
local first,note=assert(B.convert(entry,'red',data))
check(first.species=='PIKACHU' and first.moves[1].id=='FLY' and first.moves[1].pp==15 and first.ot=='RetroRecomp',
 'Gen 1 gifts resolve their species and special FLY move using the original edition definitions')
check(note:find('Gift code',1,true) and not first.eggSteps,'the gift keeps explicit provenance without inventing a Gen 1 egg')
local second=assert(B.convert(entry,'red',data))
check(S.encode(first)==S.encode(second) and S.encode(entry)==original,'all devices materialize the same gift without mutating its receipt')
local missing={pokemon=data.pokemon,moves={THUNDERSHOCK=data.moves.THUNDERSHOCK},items={},constants={}}
check(not B.convert(entry,'red',missing),'an unavailable event move preserves the gift instead of silently replacing its moves')
local egg=S.decode(original);egg.source.version='crystal';egg.origin.generation=2;egg.origin.shiny=true;egg.origin.isEgg=true;egg.canonical.moves={}
local baby=assert(B.convert(egg,'crystal',data))
check(baby.eggSteps==2560 and baby.level==5 and baby.dvs.defense==10 and baby.dvs.special==10 and baby.shiny,
 'a Gen 2 shiny egg has native hatch steps, hatch level and actual shiny DVs')
check(not B.convert(egg,'red',data),'Gen 1 cannot receive an egg even when its species exists there')
def.baseStats.spatk=50;def.baseStats.spdef=40;def.evYield={};def.abilities={'STATIC'}
local Stats=require('src.pokemon.Stats')
for _,version in ipairs({'emerald','platinum','black'}) do
 local gift=S.decode(S.encode(egg));gift.source.version=version;gift.origin.generation=require('src.core.GameVersion').generation(version)
 local modern=assert(B.convert(gift,version,data))
 check(modern.ivs and modern.personality and Stats.isShinyGen3(modern.personality,modern.otId)
   and modern.eggSteps>0 and modern.level==(gift.origin.generation>=4 and 1 or 5),
   'Gen '..gift.origin.generation..' shiny eggs use actual shiny personalities and their hatch level')
end
local bad=S.decode(original);bad.origin.shiny=true
check(not R.build(bad,'PIKACHU',data,'red'),'a malformed Gen 1 shiny claim is rejected')
local bytes=S.encode(egg);local digest=love.data.hash('sha256',bytes)
local receipt={id='11111111-1111-4111-8111-111111111111',title='Shiny egg',entry=bytes,digest=digest}
local received=assert(G.keep(receipt));check(received.id==digest,'a server receipt stores its immutable Bank entry')
check(G.keep(receipt).id==digest,'replaying the receipt restores the same Bank identity')
local count=0;for path in pairs(files) do if path:match('^bank/entries/[a-f0-9]+%.lua$') then count=count+1 end end
check(count==1,'retrying a redemption never adds a second local Bank entry')
permitted=false;check(not G.keep(receipt),'gift storage requires a linked confirmed account')
print('Gift codes: '..n..' checks passed')
