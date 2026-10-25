package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local R=require('src.storage.WonderReward');local B=require('src.storage.PokemonBank')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local f=assert(io.open('tests/engine/fixtures/wonder_reward.lua','rb'));local bytes=f:read('*a');f:close()
local entry=assert(B.decode(bytes))
check(S.encode(entry)==bytes,'server-created reward bytes match the native canonical serializer exactly')
local original=S.encode(entry)
local def={dex=entry.canonical.dex,baseStats={hp=45,attack=49,defense=49,speed=45,special=65},growthRate='MEDIUM_FAST',
  level1Moves={'TACKLE'},learnset={{level=7,move='GROWL'}},catchRate=45}
local data={pokemon={NATIVE_SPECIES=def},moves={TACKLE={pp=35},GROWL={pp=40}},items={},constants={}}
local first,note=B.convert(entry,'red',data)
check(first and first.species=='NATIVE_SPECIES' and first.ot=='RetroRecomp' and first.stats.hp>0 and first.hp==first.stats.hp,
  'a system encounter resolves its national species into a healthy native Pokémon with the system OT')
check(#first.moves>=1 and first.moves[1].id=='TACKLE' and first.moves[1].pp==35 and note:find('System Wonder Trade',1,true),
  'moves and PP come from the native learnset and the system origin stays explicit')
local second=assert(B.convert(entry,'red',data))
check(S.encode(first)==S.encode(second) and S.encode(entry)==original,'another device gets identical genetics and the immutable receipt stays unchanged')
def.baseStats.spatk=65;def.baseStats.spdef=65;def.evYield={};def.abilities={'OVERGROW'}
local modern=assert(B.convert(entry,'emerald',data))
check(modern.ivs and not modern.dvs and modern.personality and modern.abilitySlot==1 and modern.ot=='RetroRecomp',
  'modern cartridges receive their native IV/personality/ability representation')
for _,iv in pairs(modern.ivs) do assert(iv>=0 and iv<=31 and iv%1==0,'native IV range') end
check(not B.convert(entry,'red',{pokemon={},moves={},items={}}),'an unsupported species is preserved in Bank rather than replaced with a different roll')
local bad=S.decode(original);bad.origin.seed='invalid'
check(not B.convert(bad,'emerald',data),'a malformed system seed cannot produce a partial monster')
check(not R.build(entry,'UNKNOWN',data),'missing native species data cannot fabricate a reward')
print('System Wonder Trade reward: '..n..' checks passed')
