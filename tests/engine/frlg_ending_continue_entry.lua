-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=require('src.script.Gen3Commands')
for _,edition in ipairs{'firered','leafgreen'}do
 for _,ending in ipairs{false,true}do
  local f=require('tests.checkpoint_fixture').boot(edition,3)
  local g,w=f.game,f.world
  g.data.constants.gen3FRLGBehaviours={}
  g.data.constants.gen3HealLocations={{index=1,outdoor=true,map='FIX_TOWN',x=2,y=3,
   respawn={map='FIX_TOWN',x=2,y=3}}}
  local loaded=require('src.mods.Merge').deepCopy(g.save)
  loaded.player.map='FIX_ROUTE';loaded.player.x=2;loaded.player.y=3
  loaded.specialSaveWarpFlags=ending and 1 or 0
  loaded.continueGameWarp={map='FIX_TOWN',x=2,y=3}
  loaded.gen3Vars={[0x4008]=48,[0x4064]=29}
  loaded.flags.FLAG_G3_0011=true;loaded.flags.FLAG_G3_0805=true
  loaded.flags.FLAG_G3_0827=true
  for _,mon in ipairs(loaded.party)do require('src.battle.BattleState').stampOT(loaded,mon)end
  local kept=true;if ending then kept=nil end
  local party=require('src.core.SaveSerializer').encode(loaded.party)
  local inventory=require('src.core.SaveSerializer').encode(loaded.inventory)
  local apply=g.applyOptions;g.applyOptions=function()end -- no window/audio device in this fixture
  g:restoreSave(loaded)
  g.applyOptions=apply
  T.eq(w.map.id,ending and'FIX_TOWN'or'FIX_ROUTE','only the authenticated Hall bit changes the destination')
  T.eq(w.gen3FrlgContinuing==true,not ending,'Hall continueGameWarp is fresh entry; ordinary Continue restores the field')
  T.eq(C.getVar(g.save,0x4008),ending and 0 or 48,'only the native ending warp resets temporary vars')
  T.eq(g.save.flags.FLAG_G3_0011,kept,'only the ending warp resets temporary flags')
  T.eq(g.save.flags.FLAG_G3_0805,kept,'only the ending warp clears active Strength')
  T.eq(C.getVar(g.save,0x4064),29,'permanent story variables survive both branches')
  T.eq(g.save.flags.FLAG_G3_0827,true,'permanent badges survive')
  T.eq(require('src.core.SaveSerializer').encode(g.save.party),party,'the entry cannot heal or replace the party')
  T.eq(require('src.core.SaveSerializer').encode(g.save.inventory),inventory,'the entry cannot edit inventory')
  f.close()
 end
end
T.finish('Actual FRLG restoreSave ending-warp entry and ordinary Continue isolation')
