-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local G=require('src.script.Gen3Commands')
local V=require('src.core.GameVersion');local S=require('src.core.SaveSerializer');local old=V.get()
local function mon(n,opts)
  local m={species='OWNED_SPECIES_'..n,nickname='OWNED NAME '..n,level=10,hp=1,stats={hp=30},moves={}}
  for k,v in pairs(opts or{})do m[k]=v end;return m
end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  local party={mon(1),mon(2,{ribbons={champion=true,cool=2}}),mon(3,{isEgg=true}),
    mon(4,{egg=true,ribbons={artist=true}}),mon(5,{isEgg=true,ribbons={champion=true,marine=true}}),
    mon(6,{ribbons={champion=false,marine=true}})}
  local save={version=edition,party=party,flags={},player={}}
  local frlg=edition=='firered'or edition=='leafgreen'
  local data={constants=frlg and{}or{gen3GameClear={flag=edition=='emerald'and 0x864 or 0x804}}}
  local game={data=data,save=save};local ctx={game=game,save=save}
  local handler=assert(G.SPECIALS[frlg and(0x1000+272)or 275])
  local priorExisting=S.encode(party[5].ribbons)
  handler(ctx)
  T.eq(party[1].ribbons.champion,true,edition..': regular newly inducted mon receives Champion')
  T.eq(party[2].ribbons.champion,true,'previous Champion retained');T.eq(party[2].ribbons.cool,2,'other ranks retained')
  T.eq(party[3].ribbons,nil,'isEgg representation never allocates or awards ribbons')
  T.eq(party[4].ribbons.champion,nil,'egg representation cannot receive Champion')
  T.eq(party[4].ribbons.artist,true,'other egg metadata remains unchanged')
  T.eq(S.encode(party[5].ribbons),priorExisting,'existing saved egg attributes are not silently erased')
  T.eq(party[6].ribbons.champion,true,'ordinary false Champion flag is awarded')
  T.eq(party[6].ribbons.marine,true,'ordinary unrelated ribbon preserved')
  T.eq(save.hallOfFame,1,'actual induction still recorded')
  T.eq(save.flags[G.flagKey(frlg and 0x82c or edition=='emerald'and 0x864 or 0x804)],true,'native edition clear flag set')
  for i,m in ipairs(party)do
    T.eq(m.hp,30,'party still healed');T.eq(m.species,'OWNED_SPECIES_'..i,'stable species ID preserved')
    T.eq(m.nickname,'OWNED NAME '..i,'custom name preserved')
  end
end
V.set(old)
T.finish('Champion awards exclude both egg forms through all five native League entry points')
