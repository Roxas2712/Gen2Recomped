-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local copy=require('src.mods.Merge').deepCopy
local encode=require('src.core.SaveSerializer').encode

for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 for _,mode in ipairs{'warp','connection','continue','checkpoint','reload','reload-change'}do
  local f=Fixture.boot(edition,3);local g,w=f.game,f.world
  local id='OWNED_SCRATCH_ENTRY_'..edition..'_'..mode
  local def=copy(g.data.maps.FIX_TOWN);def.id=id;def.connections={};def.warps={}
  local rock=copy(def.objects[1]);rock.index,rock.localId=3,3
  rock.name='OWNED_NEW_ROOM_BOULDER';rock.eventFlag='FLAG_G3_0013';rock.flag=0x13
  rock.x,rock.y=3,3
  local permanent=copy(rock);permanent.index,permanent.localId=4,4
  permanent.name='OWNED_PERMANENT_REMOVAL';permanent.eventFlag='FLAG_G3_0354';permanent.flag=0x354
  permanent.x,permanent.y=4,3
  def.objects={rock,permanent};g.data.maps[id]=def
  require('src.world.MapLoader').invalidateAll()
  -- An unrelated rock in the previous map used the same native TEMP_3 slot.
  g.save.flags.FLAG_G3_0013=true;g.save.flags.FLAG_G3_0354=true
  g.save.gen3Vars={[0x4008]=48,[0x4064]=29}
  local party,inventory=encode(g.save.party),encode(g.save.inventory)
  local saved=mode=='continue'or mode=='checkpoint'or mode=='reload'
  if mode=='continue'then w.continuingSave=true end
  if mode=='reload'then
   w:setMap(id,2,3,'down',{via='restore',checkpoint=true})
   w:reloadMap(id,'owned graphics reload')
  else
   w:setMap(id,2,3,'down',{via=mode=='continue'and'boot'or mode=='reload-change'and'reload'or mode,
     seamless=mode=='connection',checkpoint=mode=='checkpoint'})
  end
  local live={}
  for _,npc in ipairs(w.npcs)do live[npc.def.localId]=npc end
  T.eq(live[3]~=nil,not saved,edition..' '..mode..': the new room evaluates its own cleared TEMP flag before spawning')
  T.eq(live[4],nil,'Permanent story removals remain hidden')
  T.eq(g.save.flags.FLAG_G3_0354,true,'Permanent story flags survive entry')
  T.eq(g.save.gen3Vars[0x4064],29,'Permanent story variables survive entry')
  T.eq(g.save.flags.FLAG_G3_0013==true,saved,'Saved fields preserve their existing object-removal flag')
  T.eq(g.save.gen3Vars[0x4008],saved and 48 or nil,'Only ordinary fresh entries clear scratch variables')
  T.eq(encode(g.save.party),party,'Map entry never edits the party')
  T.eq(encode(g.save.inventory),inventory,'Map entry never edits inventory')
  if not saved and live[3] then
   T.eq(live[3].cellX,3,'A fresh object uses its own header coordinates')
   T.eq(live[3].cellY,3)
  end
  f.close()
 end
end

for _,edition in ipairs{'red','gold'}do
 local f=Fixture.boot(edition,3);local g,w=f.game,f.world
 g.save.flags.FLAG_G3_0013=true;g.save.gen3Vars={[0x4008]=48}
 w:setMap('FIX_ROUTE',2,3,'down',{via='warp'})
 T.eq(g.save.flags.FLAG_G3_0013,true,'GBA scratch handling does not run for '..edition)
 T.eq(g.save.gen3Vars[0x4008],48)
 f.close()
end
T.finish('All five GBA maps spawn against fresh scratch state and preserve saved-field removals')
