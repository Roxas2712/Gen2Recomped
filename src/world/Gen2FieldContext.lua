-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read the actual resident field. No map loads, script execution or writes.
local M={}
function M.collisionAcross(world,map,x,y)
 if map:inBounds(x,y)then return map:cellCollision(x,y)end
 if map==world.map then
  for _,neighbor in ipairs(world.neighbors or{})do
   local other=neighbor.map
   local nx=x-(neighbor.ox or (neighbor.cx or 0)*16)/16
   local ny=y-(neighbor.oy or (neighbor.cy or 0)*16)/16
   if other and other:inBounds(nx,ny)then return other:cellCollision(nx,ny)end
  end
 end
 return 0xff
end
function M.blockIndex(world,x,y)
 local map=world.map
 if not(map and map:inBounds(x,y))then return nil end
 local size=map.blockCells or 2
 local bx,by=math.floor(x/size),math.floor(y/size)
 return by*map.def.width+bx+1,map:blockAt(bx,by)
end
function M.read(world,game,mon)
 local map,p=world.map,world.player
 if not(map and p and game and game.save)then return nil end
 local facing=p.facing or 'down'
 local d=require('src.world.Collision').DELTA[facing] or {0,1}
 local x,y=p.cellX+d[1],p.cellY+d[2]
 local index,block=world:blockIndexAt(x,y)
 local save=game.save
 return {save=save,party=save.party or{},mon=mon,facing=facing,facingX=x,facingY=y,
  facingColl=world:cellCollisionAcross(map,x,y),playerColl=map:cellCollision(p.cellX,p.cellY),
  upColl=world:cellCollisionAcross(map,p.cellX,p.cellY-1),
  facingObject=world:npcAtCell(x,y),tileset=map.def.tileset,environment=map.def.environment,
  facingBlock=block,facingBlockIndex=index,canEscapeRope=world:escapePoint()~=nil,
  playerState=world:movementState(),
  alwaysOnBike=require('src.script.Flags').get(save,require('src.script.Gen2Flags').bikeFlag('bike')),
  strengthActive=world.strengthActive,dark=world.dark==true}
end
return M
