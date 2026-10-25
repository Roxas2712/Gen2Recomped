package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local old=Version.get();Version.set('crystal')
local Data=require('src.core.Data');local Map=require('src.world.Map');local API=require('src.world.WorldAPI')
local Warp=require('src.world.Warp')
local data=T.fixtures.fresh()
local home,public='PLAYERS_HOUSE1_F','PLAYERS_HOUSE_1F'
data.maps={[home]={id=home,width=2,height=2,tileset='FIX_OUT',blocks={1,2,3,4},environment=3},
 ROUTE29={id='ROUTE29',width=2,height=2,tileset='FIX_OUT',blocks={5,6,7,8},environment=2}}
Data.seedDefaults(data)
local map=Map.new(data.maps[home],data.tilesets.FIX_OUT)
local neighbor=Map.new(data.maps.ROUTE29,data.tilesets.FIX_OUT)
local npc={id=home..'_obj_1',def={index=1},cellX=1,cellY=1}
local world={isOverworld=true,map=map,player={cellX=1,cellY=1,facing='up'},npcs={npc},neighbors={{map=neighbor,cx=4,cy=0}}}
local game={data=data,save={},overworld=world};local api=API.new(game,'reader_probe')
T.eq(api:current().mapId,public,'snapshot exposes real canonical Map.id')
local block=api:activeBlockAt(home,0,0)
T.eq(block,1,'native active-block request reaches actual public map')
map:setBlock(0,0,9)
T.eq(api:activeBlockAt(home,0,0),9,'native alias reads live block patch')
T.eq(api:activeBlockAt(public,0,0),9,'public alias reads same live block patch')
T.eq(api:terrainAt(1,1,home).mapId,public,'native terrain query resolves actual current map')
T.eq(api:terrainAt(1,1,'ROUTE29').mapId,'ROUTE_29','native neighbor query resolves loaded public map')
T.eq(api:npc(home,1).id,npc.id,'native NPC query admits active canonical map')
T.eq(api:npc(public,1).id,npc.id,'public NPC query preserves native object identity')
data.maps.VARIANT={id='VARIANT',sourceId=home}
T.eq(api:activeBlockAt('VARIANT',0,0),nil,'provenance alone cannot admit stale/variant block request')
T.eq(api:terrainAt(1,1,'VARIANT'),nil,'unshared variant is not a loaded map')
T.eq(api:npc('VARIANT',1),nil,'unshared variant cannot access active NPC')
local carpets={edgeMaps={},function2Maps={home},function2Tilesets={},tiles={up={7}},ssAnneBow={map='OTHER',tile=0}}
local carpetMap={id=public,def=data.maps[public],heightCells=4,widthCells=4,cellTile=function()return 7 end}
T.eq(Warp.extraCheck(carpetMap,carpets,1,1,'up',data),true,'native map carpet exception recognizes public physical identity')
carpets.edgeMaps={home}
T.eq(Warp.extraCheck(carpetMap,carpets,1,1,'up',data),false,'native map edge exception still takes precedence')
Version.set('red')
T.eq(Warp.extraCheck(carpetMap,carpets,1,1,'up',data),false,'other generations do not inherit Gen2 map aliases')
Version.set(old)
T.finish('Gen2 active/neighbor/NPC reads and native warp identity guards')
