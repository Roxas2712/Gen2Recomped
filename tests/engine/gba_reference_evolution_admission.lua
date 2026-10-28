-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local UI=require('src.ui.Gen3NativeEvolution')
local V=require('src.core.GameVersion');local old=V.get();local S=require('src.core.SaveSerializer')
for _,v in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(v)
 local panel={images={message='OWNED_PANEL.png'}};local rs=v=='ruby'or v=='sapphire'
 if rs then panel.version=v end
 local constants={gen3Evolution={evolving='OWNED_START',congratulations='OWNED_END',stopped='OWNED_STOP'},
  gen3BattleTerrain={images={BUILDING='OWNED_BG.png'},evolutionBackground=require('src.import.Gen3EvolutionBackground').PATH}}
 constants[rs and'gen3RsBattlePanel'or'gen3BattleTextbox']=panel
 local game={data={constants=constants,pokemon={MAGIKARP={index=129},GYARADOS={index=130},CUSTOM={}}}}
 local mon={species='MAGIKARP',nickname='A%{B}'};local before=S.encode({constants=constants,mon=mon})
 T.eq(UI.available(game,mon,'GYARADOS'),true,'actual family panel selects reference evolution: '..v)
 T.eq(S.encode({constants=constants,mon=mon}),before,'admission never rewrites the party or cache')
 T.eq(UI.available(game,mon,'CUSTOM'),false,'custom species without a native picture ID keep their view')
 local clean=constants.gen3BattleTerrain.evolutionBackground;constants.gen3BattleTerrain.evolutionBackground=nil
 T.eq(UI.available(game,mon,'GYARADOS'),false,'full terrain with battle platforms cannot substitute for clean evolution layer')
 constants.gen3BattleTerrain.evolutionBackground=clean
 panel.images.message=nil;T.eq(UI.available(game,mon,'GYARADOS'),false,'missing native message panel cannot select invisible scene');panel.images.message='OWNED_PANEL.png'
 if rs then panel.version=v=='ruby'and'sapphire'or'ruby';T.eq(UI.available(game,mon,'GYARADOS'),false,'foreign RS panel rejected');panel.version=v end
 V.set('gold');T.eq(UI.available(game,mon,'GYARADOS'),false,'Gen2 retains its own evolution')
 V.set('diamond');T.eq(UI.available(game,mon,'GYARADOS'),false,'Gen4 retains its own evolution')
end
V.set(old);T.finish('reference evolution admission uses RS raw panels and E/FRLG native panels')
