-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Names=require('src.core.Gen2MapNames')
local Identity=require('src.core.MapIdentity')
local Merge=require('src.mods.Merge')
local World=require('src.world.OverworldController')
local original=Version.get()
local function fixture()
 local maps={}
 for _,id in ipairs({'ROUTE29','ROUTE46','ROOM1_F'})do
  local row={id=id,width=3,height=2,blocks={1,1,1,1,1,1},connections={}}
  maps[id]=row
  local name=Identity.normalize(id);local alias=Merge.deepCopy(row)
  alias.id,alias.sourceId=name,id;maps[name]=alias
 end
 maps.ROUTE29.connections={north={map='ROUTE46',offset=1},east={map='ROOM1_F',offset=-1}}
 -- The actual seed adapter copies an entire native definition, including
 -- its source-addressed connections, before public names are published.
 maps.ROUTE_29.connections=Merge.deepCopy(maps.ROUTE29.connections)
 return {maps=maps}
end
for _,edition in ipairs({'gold','silver','crystal'})do
 Version.set(edition)
 local data=fixture();Names.publish(data)
 local root=data.maps.ROUTE_29
 local loaded={}
 for _,neighbor in ipairs(World.computeNeighbors(data.maps,root.id,1))do
  loaded[neighbor.id]=neighbor
 end
 T.check(loaded.ROUTE_46~=nil,edition..' native planner loads actual north map')
 T.check(loaded.ROOM_1F~=nil,edition..' native planner loads actual east map')
 for dir,connection in pairs(root.connections)do
  local target=data.maps[connection.map]
  T.eq(connection.map,target.id,dir..' public edge names its loaded runtime map')
  T.check(loaded[connection.map]~=nil,dir..' renderer dependency joins the native resident map')
 end
 T.eq(loaded.ROUTE_46.ox,32,'north offset remains in native blocks')
 T.eq(loaded.ROUTE_46.oy,-64,'north extent remains unchanged')
 T.eq(loaded.ROOM_1F.ox,96,'east seam remains unchanged')
 T.eq(loaded.ROOM_1F.oy,-32,'negative strip offset is preserved')
 local edge=root.connections.north
 edge.map='ROUTE46';edge.mapId='ROUTE46';Names.publish(data)
 T.eq(edge.map,'ROUTE_46','publication refreshes an edited native reference')
 T.eq(edge.mapId,'ROUTE_46','existing alternate target field follows the same physical map')
 local list={{map='ROUTE46',offset=-2},{map='ROOM1_F',offset=3}}
 root.connections.west={list=list};Names.publish(data)
 T.eq(list[1].map,'ROUTE_46','multi-strip first target uses runtime identity')
 T.eq(list[2].map,'ROOM_1F','multi-strip second target uses runtime identity')
 T.eq(list[1].offset,-2,'publication does not rescale strip offsets')
 -- Source numeric group/map coordinates are metadata, not string identities.
 root.connections.south={map=7,mapId='ROUTE46',offset=0};Names.publish(data)
 T.eq(root.connections.south.map,7,'numeric source map index is preserved')
 T.eq(root.connections.south.mapId,'ROUTE_46','string target beside numeric source metadata is published')
 -- An authored variant is a separate object even when it declares source
 -- provenance. It must never be folded into the physical source map.
 local variant=Merge.deepCopy(data.maps.ROUTE_46)
 variant.id,variant.sourceId='AUTHORED_VARIANT','ROUTE46'
 data.maps.AUTHORED_VARIANT=variant
 root.connections.east={map='AUTHORED_VARIANT',offset=0}
 root.connections.west={map='UNKNOWN_TARGET',offset=0};Names.publish(data)
 T.eq(root.connections.east.map,'AUTHORED_VARIANT','authored variant remains independently addressable')
 T.eq(root.connections.west.map,'UNKNOWN_TARGET','missing target is never guessed')
 T.eq(data.maps.AUTHORED_VARIANT,variant,'publication does not replace authored geometry')
end
for _,edition in ipairs({'red','emerald','firered','platinum'})do
 Version.set(edition);local data=fixture();local edge=data.maps.ROUTE29.connections.north
 T.eq(Names.publish(data),false,edition..' publication stays generation scoped')
 T.eq(edge.map,'ROUTE46',edition..' connection contract remains unchanged')
end
Version.set(original)
T.finish('native Gen2 connection targets match loaded map identities')
