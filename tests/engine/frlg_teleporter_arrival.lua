-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Map=require('src.world.Map');local Tiles=require('src.render.Gen3Tiles')
local source=string.rep(string.char(0,0,0,0),272)..string.char(0x67,0,0,0)
local tiles=setmetatable({metatilesInPrimary=640,primary={},secondary={sourceAttributes=source,
 sourceAttributeBytes=4,sourceBehaviorMask=511}},Tiles)
local map=setmetatable({tileset={behaviourBytes=true},doorTiles={[0x60]=true},
 renderer={gen3={tiles=tiles}},inBounds=function(_,x,y)return x==10 and y==20 end,
 blockAt=function()return 912 end,cellBehaviour=function()return 0x60 end,
 frlgWarpDirection=function()return nil end},Map)
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 T.eq(map:sourceBehaviourAt(10,20),0x67,'retained original REGULAR_WARP survives normalized CAVE_DOOR')
 T.eq(map:isDoorTileCell(10,20),false,'Silph cross-floor pad cannot auto-step south')
 T.eq(map:warpPadOrHoleAt(10,20),'pad','cross-floor pad uses spin departure and arrival')
 tiles.secondary.sourceAttributes=string.rep(string.char(0,0,0,0),272)..string.char(0x60,0,0,0)
 T.eq(map:isDoorTileCell(10,20),true,'real cave doors retain their ordinary step-out')
 T.eq(map:warpPadOrHoleAt(10,20),nil)
 tiles.secondary.sourceAttributes=source
end
V.set('sapphire');T.eq(map:isDoorTileCell(10,20),true,'Hoenn normalization is unchanged')
T.eq(map:sourceBehaviourAt(9,20),nil)
T.finish('FRLG cross-floor teleporter reads original behavior without changing normalized collision')
