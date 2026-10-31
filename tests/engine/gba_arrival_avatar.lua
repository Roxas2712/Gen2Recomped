-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local copy=require('src.mods.Merge').deepCopy
local encode=require('src.core.SaveSerializer').encode
local Music=require('src.core.Music')
local playMap=Music.playMap

for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 for _,terrain in ipairs{
  {name='sea',elevation=1,surf=true},
  {name='dry',elevation=3,surf=false},
  {name='shallow',elevation=3,surf=false},
  {name='bridge',elevation=15,surf=false},
  {name='blocked-water',elevation=1,collision=1,surf=false},
  {name='underwater',elevation=3,mapType='UNDERWATER',surf=false,dive=true},
  {name='numeric-underwater',elevation=1,mapType=5,surf=false,dive=true},
 }do
  for _,mode in ipairs{'warp','connection','continue','checkpoint','reload','reload-change'}do
   local f=Fixture.boot(edition,3);local g,w=f.game,f.world
   local id='OWNED_AVATAR_'..edition..'_'..terrain.name..'_'..mode
   local def=copy(g.data.maps.FIX_TOWN)
   def.id,def.objects,def.warps,def.connections=id,{},{},{}
   def.mapType=terrain.mapType or 'ROUTE'
   def.elevationCells={};def.collisionCells={}
   for i=1,def.width*def.height*4 do
    def.elevationCells[i]=terrain.elevation;def.collisionCells[i]=terrain.collision or 0
   end
   g.data.maps[id]=def;require('src.world.MapLoader').invalidateAll()
   local preserve=mode=='checkpoint'or mode=='reload'
   -- Deliberately inconsistent previous/saved mode reproduces the cave-to-sea
   -- script warp and the old checkpoint written while standing on the sea.
   local incomingSurf=not terrain.surf
   local incomingDive=not terrain.dive and true or nil
   w.player.surfing,w.player.diving=incomingSurf,incomingDive
   g.save.player.surfing=incomingSurf
   local party,inventory=encode(g.save.party),encode(g.save.inventory)
   local heard
   Music.playMap=function(_,_,_,surfing)heard=surfing end
   if mode=='continue'then w.continuingSave=true end
   if mode=='reload'then
    w:setMap(id,2,3,'down',{via='restore',checkpoint=true})
    w:reloadMap(id,'owned avatar graphics reload')
   else
    w:setMap(id,2,3,'down',{via=mode=='continue'and'boot'or mode=='reload-change'and'reload'or mode,
      seamless=mode=='connection',checkpoint=mode=='checkpoint'})
   end
   local expectedSurf=terrain.surf
   local expectedDive=terrain.dive or nil
   if preserve then expectedSurf,expectedDive=incomingSurf,incomingDive end
   T.eq(w.player.surfing,expectedSurf,edition..' '..terrain.name..' '..mode..': arrival avatar')
   T.eq(w.player.diving,expectedDive,'Underwater state follows the destination except saved field rebuilds')
   T.eq(g.save.player.surfing,incomingSurf,'Arrival does not rewrite the durable avatar flag')
   T.eq(encode(g.save.party),party,'Party remains unchanged')
   T.eq(encode(g.save.inventory),inventory,'Inventory remains unchanged')
   if mode~='connection'and mode~='reload'then
    T.eq(heard,expectedSurf,'Map music observes the corrected avatar')
   end
   local captured=copy(g.save);w:captureSave(captured)
   T.eq(captured.player.surfing,expectedSurf,'A later ordinary save captures the live arrival mode')
   Music.playMap=playMap;f.close()
  end
 end
end

for _,edition in ipairs{'red','gold'}do
 local f=Fixture.boot(edition,3);local g,w=f.game,f.world
 for _,surfing in ipairs{false,true}do
  g.save.player.surfing=surfing
  w:setMap('FIX_ROUTE',2,3,'down',{via='boot'})
  T.eq(w.player.surfing,surfing,edition..' keeps its own persisted surf semantics')
 end
 f.close()
end
T.finish('All five GBA arrival avatars, Continue repair, water/land/underwater and preserved field rebuilds')
