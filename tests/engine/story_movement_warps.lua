-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Movement=require('tests.drivers.story_movement')
local function fixture(width,height,warps,forced)
  local map={id='OWN_TEST_MAP'}
  function map:inBounds(x,y)return x>=0 and y>=0 and x<width and y<height end
  function map:warpAtCell(x,y)return warps[x..','..y]end
  function map:forcedMovementAt(x,y)return forced and forced[x..','..y]end
  local player={cellX=0,cellY=1,elevation=3}
  local world={map=map,player=player,entities={},scriptMoves={}}
  local game={overworld=world,stack={top=function()return world end},input={
    overlayPressed=function()error('Path queries must not send input')end}}
  local collision={mayEnter=function(_,_,_,x,y)return map:inBounds(x,y)end}
  return Movement.new(game,{},collision,function()error('Path queries must not record input')end),player,map
end
local function avoids(path,x,y,blocked)
  if not path then return false end
  local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  for _,dir in ipairs(path)do
    x=x+delta[dir][1];y=y+delta[dir][2]
    if blocked[x..','..y]then return false end
  end
  return true
end
local movement,player=fixture(5,3,{['2,1']={}})
local path=movement.pathTo(4,1)
T.check(path and#path==6 and avoids(path,0,1,{['2,1']=true}),
  'walk around an intermediate stair using a shortest safe detour')
T.eq(player.cellX,0);T.eq(player.cellY,1);T.eq(player.elevation,3,'planning leaves the player untouched')
T.eq(table.concat(movement.pathTo(2,1),','),'right,right','an explicitly requested stair remains reachable')
movement,player=fixture(5,3,{['0,1']={},['2,1']={}})
T.eq(#movement.pathTo(4,1),6,'a continued save can walk off its arrival warp')
movement,player=fixture(3,1,{['1,0']={}});player.cellY=0
T.eq(movement.pathTo(2,0),nil,'a warp-only corridor cannot lead to another cell on this map')
T.eq(table.concat(movement.pathTo(1,0),','),'right','the same corridor can intentionally change maps')
movement,player=fixture(5,2,{['2,0']={}},{['1,0']={way='right'}});player.cellY=0
path=movement.pathTo(4,0)
T.check(path and#path==6 and avoids(path,0,0,{['1,0']=true,['2,0']=true}),
  'forced movement cannot hide an intermediate warp from the planner')
T.eq(table.concat(movement.pathTo(2,0),','),'right','a forced segment can end at the requested warp')
movement,player=fixture(5,3,{})
T.eq(table.concat(movement.pathTo(4,1),','),'right,right,right,right','ordinary routes keep their original input path')
T.finish('read-only story paths, intermediate warps, explicit map exits and forced movement')
