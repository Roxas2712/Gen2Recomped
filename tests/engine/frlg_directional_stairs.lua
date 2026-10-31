-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Map=require('src.world.Map');local World=require('src.world.OverworldController')
local Warp=require('src.world.Warp')
local behavior=0;local event={def={destMap='NEXT',destWarp=1}};local calls={}
local map=setmetatable({id='HERE',def={generation=3},tileset={warpsAreEvents=true,behaviourBytes=true},
 cellBehaviour=function()return behavior end,warpAtCell=function()return event end},Map)
local world={map=map,player={cellX=10,cellY=13},takeWarp=function(_,def)calls[#calls+1]=def end}
local native={[0x62]='right',[0x63]='left',[0x64]='up',[0x65]='down',
 [0xEC]='right',[0xED]='left',[0xEE]='right',[0xEF]='left'}
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 for b,wanted in pairs(native)do
  behavior=b;T.eq(map:arrowWarpDirAt(10,13),wanted,'early input uses the same FRLG direction as blocked-edge warp checks')
  for _,dir in ipairs{'up','right','down','left'}do
   calls={};T.eq(World.checkGen3ArrowWarp(world,dir),dir==wanted,'actual input admission handles open floor beyond a side stair')
   T.eq(#calls,dir==wanted and 1 or 0)
   if dir==wanted then T.eq(calls[1],event.def)end
   T.eq(Warp.extraCheck(map,{},10,13,dir,{}),dir==wanted,'early and blocked-step paths agree')
  end
 end
 behavior=0x67;calls={};T.eq(map:arrowWarpDirAt(10,13),nil,'regular teleport pads remain arrival events')
 T.eq(World.checkGen3ArrowWarp(world,'down'),false);T.eq(#calls,0)
 behavior=0xEC;local retained=event;event=nil
 T.eq(World.checkGen3ArrowWarp(world,'right'),false,'a stair image without a warp event cannot teleport')
 event=retained
 map.tileset.arrowWarpBehaviours={[0xEC]='left'}
 T.eq(map:arrowWarpDirAt(10,13),'left','explicit caller-owned arrow tables retain their existing override')
 map.tileset.arrowWarpBehaviours=nil
end
for _,version in ipairs{'ruby','sapphire','emerald'}do
 V.set(version);behavior=0x6D;T.eq(map:arrowWarpDirAt(10,13),'down','Hoenn retains its water-south arrow')
 behavior=0xEC;T.eq(map:arrowWarpDirAt(10,13),nil,'FRLG side stairs do not leak into Hoenn')
end
V.set('platinum');map.def.generation=4;behavior=0x63;T.eq(map:arrowWarpDirAt(10,13),nil)
V.set('crystal');map.def.generation=2;map.tileset.warpsAreEvents=false
T.eq(map:arrowWarpDirAt(10,13),nil)
T.finish('Actual FRLG directional input admission, open-floor side stairs and other-generation isolation')
