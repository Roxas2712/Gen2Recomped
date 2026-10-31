-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local S=require('src.core.SaveSerializer')
for _,edition in ipairs{'ruby','sapphire','emerald'}do
 for _,ending in ipairs{false,true}do
  local f=require('tests.checkpoint_fixture').boot(edition,3);local g,w=f.game,f.world
  g.data.constants.gen3PlayerRoom={boy='FIX_TOWN',girl='FIX_TOWN',x=2,y=3}
  local loaded=require('src.mods.Merge').deepCopy(g.save)
  loaded.player.map='FIX_ROUTE';loaded.player.x=2;loaded.player.y=3
  loaded.specialSaveWarpFlags=ending and(edition=='emerald'and 0x80 or 1)or 0
  if ending and edition~='emerald'then
   loaded.gen3RsEndingReturn={format=1,version=edition,map='FIX_TOWN',x=2,y=3}
  end
  loaded.gen3Vars={[0x4008]=48,[0x4064]=29};loaded.flags.FLAG_G3_0011=true
  loaded.gen3ObjectHomes={FIX_TOWN={[1]={x=3,y=3}},FIX_ROUTE={[1]={x=3,y=3}}}
  loaded.gen3SessionObjects={mapId='FIX_ROUTE',[1]=false}
  for _,mon in ipairs(loaded.party)do require('src.battle.BattleState').stampOT(loaded,mon)end
  local party,inventory=S.encode(loaded.party),S.encode(loaded.inventory)
  local homes=S.encode(loaded.gen3ObjectHomes.FIX_ROUTE)
  local apply=g.applyOptions;g.applyOptions=function()end
  g:restoreSave(loaded);g.applyOptions=apply
  T.eq(w.map.id,ending and'FIX_TOWN'or'FIX_ROUTE','Only the authenticated League return changes the map')
  local continuing=edition=='emerald'and w.gen3EmeraldContinuing or w.gen3RsContinuing
  T.eq(continuing==true,not ending,'A League return runs fresh entry; ordinary Continue restores the saved field')
  local expectedTemp;if not ending then expectedTemp=48 end
  T.eq(g.save.gen3Vars[0x4008],expectedTemp,'Ordinary Continue keeps temporary field vars')
  local temp=g.save.flags.FLAG_G3_0011
  T.eq(temp==true,not ending,'Only a fresh League warp clears the temporary field flag')
  T.eq(g.save.gen3Vars[0x4064],29,'Permanent story state survives both branches')
  if ending then T.eq(g.save.gen3ObjectHomes.FIX_TOWN,nil,'New home entry uses its header templates')
  else T.eq(S.encode(g.save.gen3ObjectHomes.FIX_ROUTE),homes,'Ordinary Continue keeps saved object coordinates')end
  T.eq(S.encode(g.save.party),party);T.eq(S.encode(g.save.inventory),inventory)
  f.close()
 end
end
T.finish('Actual Hoenn restoreSave distinguishes ordinary saved fields and native League return warps')
