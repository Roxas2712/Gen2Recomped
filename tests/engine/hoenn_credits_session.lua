-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion');local old=V.get()
local Shared=require('src.ui.Gen3CreditsSession');local S=require('src.core.SaveSerializer')
for _,version in ipairs{'ruby','sapphire','emerald'}do
  V.set(version)
  for _,gender in ipairs{'boy','girl',0,1}do
    local game={data={pokemon={TREECKO={index=277,dex=252},UNOWN={index=201,dex=201},UNOWN_B={index=413,dex=201},SPINDA={index=308,dex=327}}},
      save={player={gender=gender},gen3Vars={[0x4023]=2},pokedex={caught={TREECKO=true,UNOWN=1},owned={SPINDA=true},unownPersonality=101,spindaPersonality=202}}}
    local before=S.encode(game.save);local session,bindings=Shared.new(game,0x4023)
    local dex,pokemon=bindings['src.core.game3.dex'],bindings['src.core.game3.pokemon']
    T.eq(session.version,version,'own edition reaches native movie')
    T.eq(session.gender,(gender=='girl'or gender==1)and 1 or 0,'original gender encoding')
    T.eq(bindings['src.core.game3.rse.init'].var('VAR_STARTER_MON'),2,'actual native starter var supplied')
    T.eq(dex.isCaught(session.dex,277),true,'stable host caught ID becomes native index')
    T.eq(dex.isCaught(session.dex,201),true,'numeric caught bit accepted')
    T.eq(dex.isCaught(session.dex,308),true,'owned bit also counts for native movie')
    T.eq(pokemon.speciesFromNational(201),201,'base Unown wins over alternate forms')
    T.eq(dex.defaultPersonality(session.dex,201),101,'captured Unown personality retained')
    T.eq(dex.defaultPersonality(session.dex,308),202,'captured Spinda personality retained')
    T.eq(dex.defaultPersonality(session.dex,277),0,'ordinary non-form default personality')
    T.eq(S.encode(game.save),before,'constructing and reading numeric views preserves persistent save')
  end
end
V.set(old);T.finish('shared Hoenn credits preserve species IDs, gender, starter and captured form identities')
