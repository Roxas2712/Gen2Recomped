-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- RS field_tasks.c: ice row masks survive CONTINUE, but reset on a map visit.
local M = {}
local rows = {[6]=0x4001,[7]=0x4002,[8]=0x4003,[9]=0x4004,
  [12]=0x4005,[13]=0x4006,[14]=0x4007,[17]=0x4008,[18]=0x4009,[19]=0x400A}
local function record(world, game)
  local v = require('src.core.GameVersion').get()
  local map = world and world.map
  if (v~='ruby' and v~='sapphire') or not map or map.id~='MAP_G15_N00' then return end
  local ice = game.data.constants.gen3Ice
  local swap = ice and ice.swap and ice.swap[map.def.tileset]
  local trigger = ice and ice.fallTrigger and ice.fallTrigger[map.id]
  if swap and trigger then return map,swap,trigger end
end
local function mark(save,x,y)
  local id = x>=3 and x<14 and rows[y]
  if not id then return end
  local C=require('src.script.Gen3Commands')
  C.setVar(save,id,require('bit').bor(C.getVar(save,id),2^(x-3)))
end
function M.enter(world,game,continuing)
  world.rsIcePending=nil
  local map=record(world,game)
  if not map then return end
  local C=require('src.script.Gen3Commands')
  if not continuing or game.save.gen3RsIceFormat~=1 then
    for _,id in pairs(rows) do C.setVar(game.save,id,0) end
  end
  if continuing and game.save.gen3RsIceFormat~=1 then
    -- Earlier fork saves kept exactly these visited cells in gen3ThinIce.
    -- Retain that witnessed puzzle state when upgrading to native row masks.
    local old=game.save.gen3ThinIce and game.save.gen3ThinIce[map.id]
    for key,visited in pairs(old or {}) do
      if visited and type(key)=='number' then mark(game.save,key%map.widthCells,math.floor(key/map.widthCells)) end
    end
  end
  game.save.gen3RsIceFormat=1
end
function M.restore(world,game)
  local map,swap=record(world,game)
  if not map then return false end
  local C=require('src.script.Gen3Commands');local bit=require('bit')
  local cells={}
  for y,id in pairs(rows) do
    local mask=C.getVar(game.save,id)
    for x=3,13 do
      if bit.band(mask,2^(x-3))~=0 then
        cells[y*map.widthCells+x]=true
        map:setBlock(x,y,swap.cracked)
      end
    end
  end
  game.save.gen3ThinIce=game.save.gen3ThinIce or {}
  game.save.gen3ThinIce[map.id]=cells
  world:redrawBlocks(map)
  return true
end
function M.step(world,game)
  local map,swap,trigger=record(world,game)
  if not map then return nil end
  local p=world.player
  if not p or p.surfing or world.rsIcePending then return false end
  local b=map:cellBehaviour(p.cellX,p.cellY)
  local thin=map:isThinIceCell(p.cellX,p.cellY)
  if not thin and b~=swap.crackedBehaviour then return false end
  local C=require('src.script.Gen3Commands')
  C.setVar(game.save,trigger.var,thin and C.getVar(game.save,trigger.var)+1 or trigger.value or 0)
  world.rsIcePending={x=p.cellX,y=p.cellY,delay=4,broken=not thin,map=map.id}
  return not thin
end
function M.tick(world,game)
  local pending=world.rsIcePending
  if not pending then return end
  local map,swap=record(world,game)
  if not map or pending.map~=map.id then world.rsIcePending=nil;return end
  if pending.delay>0 then pending.delay=pending.delay-1;return end
  world.rsIcePending=nil
  map:setBlock(pending.x,pending.y,pending.broken and swap.hole or swap.cracked)
  world:redrawBlocks(map)
  if not pending.broken then
    mark(game.save,pending.x,pending.y)
    world:thinIceState(map.id)[pending.y*map.widthCells+pending.x]=true
  end
  require('src.core.Sound').playSe(game.data,pending.broken and 'SE_ICE_BREAK' or 'SE_ICE_CRACK')
end
return M
