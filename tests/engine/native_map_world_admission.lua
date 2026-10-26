-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Session=require('src.compat.gen1.NativeSession')
local Stack=require('src.core.StateStack')
local Maps=require('src.core.game3.map')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  local f=require('tools.map-runtime.fixture').new(edition)
  local stack=setmetatable({},{__index=Stack});stack:init();stack:setWorldOwner({})
  f.game.stack=stack;stack:push(f.world)
  package.loaded['src.core.Game']=f.game;Maps.release()
  T.eq(Session.world(f.game),f.world)
  local current=assert(Maps.currentDef())
  T.eq(current.id,f.mapId);T.eq(current.midLayout.width,4);T.eq(current.midLayout.trueWidth,3)
  T.eq(f.views:current().nativeId,f.map.id,'snapshot provider follows the same admitted world')
  f.world.player={cellX=1,cellY=1}
  local x,y=Maps.warmRect();T.check(type(x)=='number'and type(y)=='number','warm bounds use the persistent native player')
  local cover={};stack:push(cover)
  T.eq(Maps.currentDef(),current,'covering UI cannot retire the native map view')
  T.eq(f.views:current().nativeId,f.map.id)
  local entering={isOverworld=true,map=f.neighbor,player={}}
  Session.withWorld(f.game,entering,function()
    T.eq(Maps.currentDef().id,f.neighborId,'entry scope takes priority over admitted world')
    T.eq(f.views:current().nativeId,f.neighbor.id)
  end)
  T.eq(Maps.currentDef().id,f.mapId,'native map observation returns after the scope')
  stack:pop();stack.worldState=nil
  T.eq(Maps.currentDef(),nil,'unadmitted convenience pointers cannot revive a map')
  T.eq(f.views:current(),nil)
  stack.worldState=f.world
  local before=f.game.data;f.game.data={maps={}}
  T.eq(Maps.currentDef(),nil,'dataset replacement still refuses old native maps')
  f.game.data=before;Maps.release();f.views:release()
end
package.loaded['src.core.Game']=nil
T.finish('map definitions, snapshots and warm bounds share native world admission')
