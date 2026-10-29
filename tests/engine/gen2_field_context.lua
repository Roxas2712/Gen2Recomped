-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local previous=Version.get()
local W=require('src.world.OverworldController')
local C=require('src.world.Collision');local Map=require('src.world.Map')
local Merge=require('src.mods.Merge')
Version.set('crystal')
local oldGame,gameSlot
for i=1,100 do local name,value=debug.getupvalue(W.fieldContext,i)
 if not name then break end;if name=='Game'then gameSlot,oldGame=i,value;break end
end
assert(gameSlot)
local loader=T.sdk.loadMods({'mods/source_field','mods/native_field'},{fs=T.sdk.memfs({
 ['mods/source_field/manifest.json']='{"id":"source_field","name":"Source field","version":"1.0.0","api":2,"entry":"main.lua"}',
 ['mods/source_field/main.lua']=[[
  local mod=...;mod.exports.World=require('src.world.gen2.World')
  mod.exports.P=require('src.world.gen2.Permissions')
  mod.exports.Core=require('src.core.CollPermissions')
  mod.exports.facingWater=function(world)return mod.exports.P.isWater(world:fieldContext().facingColl)end
 ]],
 ['mods/native_field/manifest.json']='{"id":"native_field","name":"Native field","version":"1.0.0","api":2,"entry":"main.lua"}',
 ['mods/native_field/main.lua']=[[
  local mod=...;mod.exports.World=require('src.world.OverworldController')
  mod.exports.P=require('src.world.Collision');mod.exports.canMove=mod.exports.P.canMove
 ]],
})})
T.eq(#loader.errors,0,'unchanged source and native namespace consumers load together')
local source,native=loader.loader.exports.source_field,loader.loader.exports.native_field
T.eq(source.World,W);T.eq(native.World,W);T.eq(source.P,C);T.eq(native.P,C)
T.eq(native.canMove,C.canMove,'native mover remains the original owner')
T.eq(source.Core,require('src.world.Gen2CollisionPermissions'))
local water={[0x20]=true,[0x21]=true,[0x22]=true,[0x24]=true,[0x25]=true,[0x26]=true,
 [0x28]=true,[0x29]=true,[0x2a]=true,[0x2c]=true,[0x2d]=true,[0x2e]=true}
for n=0x30,0x3f do water[n]=true end;for n=0xc0,0xcf do water[n]=true end
for byte=0,255 do
 T.eq(C.isWater(byte),water[byte]==true,'complete GSC water-class coverage')
 T.eq(source.Core.of(byte),C.of(byte),'core and world permission owners agree')
 T.eq(C.surfable(byte),water[byte] and 'water' or C.isLand(byte)and'land'or nil)
 T.eq(C.isLedge(byte),byte>=0xa0 and byte<=0xaf)
end
T.eq(C.isWater(0x129),true,'source permission byte wraps')
T.eq(C.isIce(0x123),false,'existing strict native terrain query remains unchanged')
for _,bad in ipairs{-1,false,{},'water',1.5,math.huge,0/0}do T.eq(C.isWater(bad),false)end
T.eq(C.of(nil),C.WALL)
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
 Version.set(edition)
 local ts={id='FIELD_CONTEXT',blocks={},collision={},walkable={0},waterTiles={0x29}}
 for i=1,80 do ts.collision[i]=0 end
 local def={id='FIELD_HOME',width=2,height=2,generation=2,blocks={1,2,3,4},tileset=ts.id,environment=2}
 local other={id='FIELD_NEXT',width=2,height=2,generation=2,blocks={5,6,7,8},tileset=ts.id,environment=2}
 local map,neighbor=Map.new(def,ts),Map.new(other,ts)
 local p={cellX=1,cellY=1,facing='right',surfing=false}
 local w=setmetatable({map=map,player=p,npcs={},neighbors={{map=neighbor,ox=64,oy=0}},strengthActive=false,dark=false},{__index=W})
 local mon={species='FIELD_MON'}
 local game={save={party={mon},flags={}},data={maps={[def.id]=def,[other.id]=other},tilesets={[ts.id]=ts}}}
 debug.setupvalue(W.fieldContext,gameSlot,game)
 local before=Merge.deepCopy(game.save)
 local function put(m,x,y,coll)
  local block=m:blockAt(math.floor(x/2),math.floor(y/2))
  ts.collision[block*4+(y%2)*2+x%2+1]=coll
 end
 put(map,2,1,0x29);put(map,1,1,0x18);put(map,1,0,0x23)
 local ctx=w:fieldContext(mon)
 T.eq(ctx.save,game.save);T.eq(ctx.party,game.save.party);T.eq(ctx.mon,mon)
 T.eq(ctx.facing,'right');T.eq(ctx.facingX,2);T.eq(ctx.facingY,1)
 T.eq(ctx.facingColl,0x29);T.eq(ctx.playerColl,0x18);T.eq(ctx.upColl,0x23)
 T.eq(ctx.facingBlockIndex,2);T.eq(ctx.facingBlock,2)
 T.eq(ctx.tileset,ts.id);T.eq(ctx.environment,2)
 T.eq(source.facingWater(w),true,'unchanged comfort consumer sees real native water')
 T.eq(ctx.canEscapeRope,false);T.eq(ctx.dark,false);T.eq(ctx.alwaysOnBike,false)
 map:setBlock(1,0,8);put(map,2,1,0x15)
 T.eq(w:fieldContext().facingBlock,8,'live runtime block edit is read')
 T.eq(source.facingWater(w),false,'runtime collision edit replaces prior water result')
 map:setBlock(1,0,2)
 local npc={cellX=2,cellY=1,def={}};w.npcs={npc}
 T.eq(w:fieldContext().facingObject,npc,'actual native occupant returned')
 npc.hidden=true;T.eq(w:fieldContext().facingObject,nil,'native absent occupant policy retained')
 p.cellX,p.cellY=3,1;put(neighbor,0,1,0x29)
 T.eq(w:fieldContext().facingColl,0x29,'resident connected map queried in translated cells')
 T.eq(w:fieldContext().facingBlockIndex,nil,'foreign block index never addresses current map')
 put(neighbor,0,1,0x07);T.eq(source.facingWater(w),false,'neighbor live collision changes observed')
 w.neighbors={};T.eq(w:fieldContext().facingColl,0xff,'unloaded boundary is closed without loading maps')
 p.cellY,p.facing=0,'up';T.eq(w:fieldContext().upColl,0xff,'unloaded upper edge closed')
 game.save.digWarp={id='FIELD_ESCAPE',x=1,y=2};w.dark=true;w.strengthActive=true
 require('src.script.Flags').set(game.save,require('src.script.Gen2Flags').bikeFlag('bike'))
 ctx=w:fieldContext();T.eq(ctx.canEscapeRope,true);T.eq(ctx.dark,true);T.eq(ctx.strengthActive,true);T.eq(ctx.alwaysOnBike,true)
 game.save.digWarp=nil;game.save.flags=before.flags
 T.same(game.save,before,'context and permission queries leave the actual save untouched')
 Version.set('firered');T.eq(w:fieldContext(),nil,'Gen3 retains its separate field rules')
end
debug.setupvalue(W.fieldContext,gameSlot,oldGame)
Version.set(previous)
T.finish('native/source GSC field context, unchanged native mover and live boundary queries')
