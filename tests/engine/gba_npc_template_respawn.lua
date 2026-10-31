-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=require('src.script.Commands')
require('src.script.Gen3Commands')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
  local f=require('tests.checkpoint_fixture').boot(edition,3)
  local g,w=f.game,f.world
  local obj={}
  for k,v in pairs(w.map.def.objects[1])do obj[k]=v end
  obj.index,obj.localId,obj.x,obj.y=4,4,6,3
  obj.eventFlag,obj.movementType='FLAG_G3_002B',8
  w.map.def.objects={obj};w.npcs={};w.entities={w.player};w.npcPool={}
  g.data.map_scripts=g.data.map_scripts or{}
  g.data.map_scripts.spawned={[w.map.id]={[4]=true}}
  g.save.flags[obj.eventFlag]=false
  w:syncObjectVisibility()
  local old=assert(w:npcByIndex(4))
  local ctx={game=g,save=g.save,overworld=w,mapId=w.map.id,gen3MapSetup=true}
  -- Oak's original map callback places him at the entrance before his walk.
  C.g3_place_perm(ctx,4,6,11);C.g3_movement_type(ctx,4,7)
  T.eq(old.cellY,11,'entry setup places the actual actor at the lab doorway')
  T.eq(obj.y,3,'entry setup preserves the imported object template')
  ctx.gen3MapSetup=nil
  old.cellX,old.cellY,old.px,old.py=6,3,96,48
  old.hidden,old.gen3Invisible=true,true
  -- The original lab scene removes him, resets his template, and clears his flag.
  C.g3_hide_object(ctx,4)
  T.eq(w:npcByIndex(4),nil,'removeobject retires the live actor')
  C.g3_place_perm(ctx,4,6,3);C.g3_movement_type(ctx,4,8)
  C.g3_clear_flag(ctx,obj.eventFlag)
  local shown=assert(w:npcByIndex(4))
  T.eq(shown.cellX,6);T.eq(shown.cellY,3,edition..' Oak respawns at the new template, not stale entry placement')
  T.eq(shown.px,96);T.eq(shown.py,48,'render and collision positions agree')
  T.eq(shown.hidden==true,false,'new spawn does not inherit retired sprite invisibility')
  T.eq(shown.gen3Invisible==true,false,'new spawn has a fresh native visibility bit')
  T.eq(g.save.flags[obj.eventFlag],false,'the original clearflag remains authoritative')
  T.eq(obj.y,3,'respawn never rewrites cartridge templates')
  T.eq(g.save.gen3ObjectHomes[w.map.id][4].y,3,'script-written template remains available')
  shown.cellX,shown.cellY,shown.px,shown.py=5,6,80,96
  w:syncObjectVisibility()
  T.eq(w:npcByIndex(4),shown,'a still-live actor retains its owner')
  T.eq(shown.cellX,5);T.eq(shown.cellY,6,'visibility refresh does not reset ordinary live movement')
  -- Unflagged script actors also respawn from their current template.
  obj.eventFlag=nil
  C.g3_hide_object(ctx,4);C.g3_place_perm(ctx,4,7,4);C.g3_show_object(ctx,4)
  shown=assert(w:npcByIndex(4))
  T.eq(shown.cellX,7);T.eq(shown.cellY,4)
  T.eq(shown.px,112);T.eq(shown.py,64)
  f.close()
end
T.finish('GBA lab scene respawns use current templates and fresh actors while live movement stays intact')
