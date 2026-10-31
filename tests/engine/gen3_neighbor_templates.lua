-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local S=require('src.core.SaveSerializer')
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=require('tests.checkpoint_fixture').boot(edition,3)
 local g,w=f.game,f.world;local key='FIX_ROUTE_obj_1'
 g.save.gen3ObjectHomes={FIX_ROUTE={[1]={x=3,y=3}},FIX_TOWN={[1]={x=7,y=6}}}
 w.npcPool[key]=nil
 local before=S.encode(g.save)
 w:rebuildNeighbors()
 local npc=assert(w.npcPool[key],'Connected original object was not built')
 T.eq(npc.cellX,5,edition..' unloaded neighbor starts at its ROM template, not another visit\'s saved home')
 T.eq(npc.cellY,9,'stale neighbor home cannot put a pooled actor in a doorway')
 T.eq(S.encode(g.save),before,'Neighbor presentation cannot rewrite saved object templates')
 local world=require('src.world.OverworldController')
 T.eq(world.objectHome(g.save,'FIX_TOWN',g.data.maps.FIX_TOWN.objects[1]).x,7,'current map still admits its own scripted template')
 npc.cellX,npc.cellY=6,10
 w:rebuildNeighbors()
 T.eq(w.npcPool[key],npc,'already resident connected actors retain their owner')
 T.eq(npc.cellX,6);T.eq(npc.cellY,10,'ordinary wandering/scripted movement is not reset on a neighbor refresh')
 f.close()
end
T.finish('Actual GBA neighbor creation isolates historical templates and preserves live actors/current-map homes')
