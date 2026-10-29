-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local previous=Version.get()
local Native=require('src.pokemon.Pokemon')
local Mon=require('src.compat.gen2.Mon')
local Fields=require('src.pokemon.Gen2MonFields')
local function fixture()
  local data=T.fixtures.fresh();data.constants.gen=2
  for _,def in pairs(data.pokemon)do
    def.baseStats.spatk,def.baseStats.spdef=41,99
  end
  data.pokemon.FIXMON_A.growthRate='SOURCE_TEST'
  data.pokemon.growthRates={SOURCE_TEST={numerator=2,denominator=1,constant=1}}
  return data
end
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
  Version.set(edition);local data=fixture()
  local genes={attack=9,defense=8,speed=7,special=6}
  local effort={hp=90,attack=200,defense=400,speed=800,special=1600}
  local slots={{id='FIX_TACKLE',pp=0,maxPp=17,custom='source-owned'}}
  local opts={dvs=genes,statExp=effort,moves=slots,nickname='SOURCE',hp=0,
    happiness=0,pokerus=0x23,item='SOURCE_ITEM',caughtLevel=0,caughtTime=2,
    caughtLocation=17,caughtByGender=1,shiny=true,
    rng=function()error('authored source genes must not spend a birth draw')end}
  local mon=Mon.new(data,'FIXMON_A',7,opts)
  T.eq(mon.dvs,genes,'source genes retain ownership '..edition)
  T.eq(mon.statExp,effort,'source effort retains ownership')
  T.eq(mon.moves,slots,'source moves retain ownership')
  T.eq(genes.hp,10,'HP derives four low gene bits')
  T.eq(mon.hp,0,'zero HP is an explicit source option')
  T.eq(mon.happiness,0,'zero happiness is explicit')
  T.eq(mon.pokerus,0x23);T.eq(mon.nickname,'SOURCE');T.eq(mon.item,'SOURCE_ITEM')
  T.eq(mon.caughtLevel,0);T.eq(mon.caughtTime,2);T.eq(mon.caughtLocation,17)
  T.eq(mon.caughtByGender,1);T.eq(mon.shiny,true)
  T.eq(mon.exp,2*7^3-1,'source coefficient evaluation reaches native experience')
  T.eq(mon.experience,mon.exp);T.eq(rawget(mon,'experience'),nil)
  T.eq(mon.maxHp,mon.stats.hp);T.eq(rawget(mon,'maxHp'),nil)
  T.eq(mon.stats.specialAttack,mon.stats.spatk)
  T.eq(mon.types,data.pokemon.FIXMON_A.types)
  T.same(mon.stats,Mon.stats(data.pokemon.FIXMON_A.baseStats,genes,7,effort))
  local seed={attack=1,defense=2,speed=3,special=4}
  local native=Native.new(data,'FIXMON_A',7,function()error('native explicit genes spend no draw')end,nil,
    {dvs=seed,moves=slots,hp=0,nickname='IGNORED',happiness=0,pokerus=35})
  T.check(native.dvs~=seed,'native explicit genes remain a validated copy')
  T.check(native.moves~=slots,'source options never leak into native birth')
  T.eq(native.hp,native.stats.hp,'native HP policy is unchanged')
  T.eq(native.nickname,nil);T.eq(native.pokerus,nil)
  T.eq(native.happiness,require('src.pokemon.Evolution').BASE_HAPPINESS)
  T.raises(function()Native.new(data,'FIXMON_A',7,nil,nil,{dvs={attack=99}})end,
    'invalid native Gen2 DV','native validation stays active')
  T.eq(Mon.new(data,'NO_SUCH_SPECIES',5),nil,'source missing species returns nil')
  local function seeded()return 2 end
  T.eq(Mon.new(data,'FIXMON_A',nil,{rng=seeded}).level,5,'source default level')
  T.eq(Mon.new(data,'FIXMON_A',-3,{rng=seeded}).level,1,'source minimum level')
  T.eq(Mon.new(data,'FIXMON_A',102,{rng=seeded}).level,100,'source maximum level')
  T.eq(Mon.new(data,'FIXMON_A',4,seeded).level,4,'existing RNG overload remains native')
  local original,draws=Mon.randomDVs,0
  Mon.randomDVs=function()draws=draws+1;return {attack=1,defense=1,speed=1,special=1}end
  local born=Mon.new(data,'FIXMON_A',5)
  Mon.randomDVs=original
  T.eq(draws,1,'source helper wrapper dispatches through the actual birth owner')
  T.eq(born.dvs.hp,15)
  local save={player={name='LOCAL',id=42}}
  local traded={ot='REMOTE',traded=true}
  T.eq(Mon.stampOT(save,traded),traded,'source OT API returns the actual mon')
  T.eq(traded.otId,nil,'unknown foreign OT id is not invented')
  T.eq(traded.otName,'REMOTE')
  local gift={};T.eq(require('src.battle.BattleState').stampOT(save,gift),nil,
    'native OT API preserves its historical no-return contract')
  T.eq(gift.otId,42);T.eq(gift.ot,'LOCAL');T.eq(gift.otName,nil,
    'source-only OT presentation must not change existing native output')
  local growthCalls=0
  data.growth_rates={SOURCE_TEST={expForLevel=function(n)
    growthCalls=growthCalls+1;return n^3 end}}
  Mon.new(data,'FIXMON_A',7,{dvs=genes})
  T.eq(growthCalls,1,'source birth evaluates a registered curve exactly once')
end
Version.set('crystal')
T.eq(Mon.MAX_DV,15);T.eq(Mon.PARTY_SIZE,6)
T.eq(Mon.WILD_NO_ITEM_THRESHOLD,192);T.eq(Mon.WILD_ITEM2_THRESHOLD,20)
local totals={none=0,common=0,rare=0};local secondDraws=0
for first=0,255 do for second=0,255 do
  local draws=0
  local item=Mon.wildItem({items={'COMMON','RARE'}},false,function(n)
    T.eq(n,256,'source wild roll keeps its byte domain')
    draws=draws+1;return draws==1 and first or second
  end)
  totals[item=='COMMON'and'common'or(item=='RARE'and'rare'or'none')]=
    totals[item=='COMMON'and'common'or(item=='RARE'and'rare'or'none')]+1
  if draws==2 then secondDraws=secondDraws+1 end
end end
T.same(totals,{none=49152,common=15104,rare=1280},'exact GSC two-byte held-item partition')
T.eq(secondDraws,16384,'second byte consumed only after no-item gate')
T.eq(Mon.wildItem({items={'FORCED'}},true,function()error('force consumes zero draws')end),'FORCED')
local observed={};local data=fixture();local genes={attack=1,defense=1,speed=1,special=1}
local mon=Mon.new(data,'FIXMON_A',5,{wild=true,random=function(n)
  observed[#observed+1]='item';return 255 end,rng=function()
  observed[#observed+1]='gene';return 1 end})
T.same(observed,{'item','item','gene','gene','gene','gene'},'source wild item precedes birth genes')
T.eq(Mon.displayName(nil),'?');T.eq(Mon.displayName({name='DISPLAY',species='ID'}),'DISPLAY')
T.eq(Mon.displayName({nickname='NICK',name='DISPLAY'}),'NICK')
local first={method='EVOLVE_LEVEL',level=5,species='FIRST'}
local second={method='LEVEL',level=4,species='SECOND'}
T.eq(Mon.evolutionAtLevel({evolutions={first,second}},5),first,'source ordered level query')
T.eq(Mon.evolutionAtLevel({evolutions={second}},5),second,'native level spelling uses same reader')
T.eq(Mon.evolutionAtLevel({evolutions={first}},4),nil)
-- Native sparse slots and source Day-Care spellings share the real records.
local list={};for i=1,9 do list[i]={species='FIXMON_A',dvs=genes}end
local save={party={[1]=list[1],[3]=list[2]},boxes={{list[3]},{mons={list[4]}}},
 dayCare={man={mon=list[5]},lady={mon=list[6]},egg=list[7]},
 daycare={mon=list[8],breed={{mon=list[9]}}},modData={unrelated={species='FIXMON_A'}}}
local seen={};Native.eachSaveMon(save,function(value)seen[value]=true end)
for _,value in ipairs(list)do T.check(seen[value],'actual save slot included')end
T.eq(seen[save.modData.unrelated],nil,'modData is never interpreted as a Pokemon registry')
Fields.bindSave(data,save)
for _,value in ipairs(list)do T.eq(value.name,data.pokemon.FIXMON_A.name,'native binding covers each real slot')end
local sourceSlots={};Mon.eachSaveMon(save,function(value)sourceSlots[value]=true end)
T.eq(sourceSlots[list[2]],nil,'source array iteration retains its first-hole boundary')
T.eq(sourceSlots[list[9]],true,'source observer can reach actual native breeding slot')
-- Both unmodified consumer namespaces load and construct side by side.
local loaded=T.sdk.loadMods({'mods/native_birth','mods/source_birth'},{data=data,fs=T.sdk.memfs({
 ['mods/native_birth/manifest.json']='{"id":"native_birth","name":"Native birth","version":"1.0.0","api":2,"entry":"main.lua"}',
 ['mods/native_birth/main.lua']=[[
   local mod=...;local P=require('src.pokemon.Pokemon')
   mod.exports.birth=function(data,rng)return P.new(data,'FIXMON_A',5,rng)end
 ]],
 ['mods/source_birth/manifest.json']='{"id":"source_birth","name":"Source birth","version":"1.0.0","api":2,"entry":"main.lua"}',
 ['mods/source_birth/main.lua']=[[
   local mod=...;local P=require('src.battle.gen2.Mon')
   mod.exports.birth=function(data,opts)return P.new(data,'FIXMON_A',nil,opts)end
 ]],
})})
T.eq(#loaded.errors,0,'native and Gen1-style consumers coexist')
local nativeDraws=0
local n=loaded.loader.exports.native_birth.birth(data,function(lo,hi)
 nativeDraws=nativeDraws+1;T.eq(lo,0);T.eq(hi,15);return 3 end)
local s=loaded.loader.exports.source_birth.birth(data,{dvs=genes,nickname='SOURCE',hp=0})
T.eq(nativeDraws,4,'native mod keeps its two-bound four-draw RNG contract')
T.eq(n.hp,n.stats.hp);T.eq(s.hp,0);T.eq(s.nickname,'SOURCE');T.eq(s.dvs,genes)
loaded.release();Version.set(previous)
T.finish('source GSC birth contracts and unchanged native-mod entry path')
