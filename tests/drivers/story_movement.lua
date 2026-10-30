-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared read-only native path planning and recorded ordinary D-pad movement.
local M={}
function M.new(game,U,Collision,getInputLog)
  local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local function freeField()
    local w=game.overworld
    return w and game.stack:top()==w and not w.player.moving and not w.player.inputLocked
      and #(w.scriptMoves or {})==0 and not(w.runner and w.runner:isRunning())
  end
  local function step(dir)
    assert(dirs[dir]);if not freeField()then return false,'event/UI is active'end
    local w=game.overworld;local map=w.map.id;local x,y=w.player.cellX,w.player.cellY
    local inputLog=getInputLog()
    local held=0;local movement
    if inputLog then movement={key=dir,heldFrames=0,releaseFrames=8,frame=U.frame()};inputLog[#inputLog+1]=movement end
    game.input:overlayPressed(dir)
    for _=1,60 do U.wait(1)
      held=held+1
      if w.map.id~=map or w.player.moving or w.player.cellX~=x or w.player.cellY~=y or not freeField()then break end
    end
    game.input:overlayReleased(dir)
    if movement then movement.heldFrames=held end
    for _=1,1200 do
      if not game.overworld.player.moving and #(game.overworld.scriptMoves or {})==0 then break end
      U.wait(1)
    end
    U.wait(8)
    return w.map.id~=map or w.player.cellX~=x or w.player.cellY~=y,'blocked or interrupted'
  end
  local function pathTo(tx,ty)
    local w=game.overworld;local map=w.map;local q={{w.player.cellX,w.player.cellY,w.player.elevation}};local seen={};local prev={}
    local function key(x,y,z)return x..','..y..','..tostring(z)end
    local function intermediateWarp(x,y)
      if (x==tx and y==ty)or(x==q[1][1]and y==q[1][2])then return false end
      return map.warpAtCell and map:warpAtCell(x,y)~=nil
    end
    seen[key(q[1][1],q[1][2],q[1][3])]=true
    local head=1
    while q[head]do
      local p=q[head];head=head+1
      if p[1]==tx and p[2]==ty then
        local path={};local k=key(tx,ty,p[3])
        while prev[k]do local e=prev[k];table.insert(path,1,e.dir);k=e.from end
        return path
      end
      for _,dir in ipairs({'up','down','left','right'})do
        local d=dirs[dir];local x,y=p[1]+d[1],p[2]+d[2]
        -- Ask the same read-only collision rules as actual movement. A raw
        -- walkable bit includes Hoenn water beneath bridges and directed walls.
        local mover=setmetatable({cellX=p[1],cellY=p[2],elevation=p[3]},{__index=w.player})
        local elevation=map.elevationAfter and map:elevationAfter(p[3],x,y,p[1],p[2])or p[3]
        local entered=map:inBounds(x,y)and Collision.mayEnter(map,w.entities or{},mover,x,y,dir)
        -- A walkable stair still ends travel on this map. Never plan a route
        -- through it when the command names a different destination.
        if entered and intermediateWarp(x,y)then entered=false end
        -- A d-pad tap ends at the conveyor's exit, not its first arrow.
        -- Simulate only read-only collision/rules; actual travel still uses
        -- ordinary input and is recorded one frame/press at a time.
        local forcedSeen={};local incoming=dir
        while entered and not w.player.surfing and map.forcedMovementAt do
          if x==tx and y==ty and map.warpAtCell and map:warpAtCell(x,y)then break end
          local row=map:forcedMovementAt(x,y);local way=row and row.way
          if not way and map.isIceCell and map:isIceCell(x,y)then way=incoming end
          if not way then break end
          local here=key(x,y,elevation)
          if forcedSeen[here]then entered=false;break end
          forcedSeen[here]=true
          local step=dirs[way];if not step then entered=false;break end
          mover=setmetatable({cellX=x,cellY=y,elevation=elevation},{__index=w.player})
          local nx,ny=x+step[1],y+step[2]
          if not map:inBounds(nx,ny)or not Collision.mayEnter(map,w.entities or{},mover,nx,ny,way)then break end
          if intermediateWarp(nx,ny)then entered=false;break end
          elevation=map.elevationAfter and map:elevationAfter(elevation,nx,ny,x,y)or elevation
          x,y=nx,ny;incoming=way
        end
        local k=key(x,y,elevation)
        if entered and not seen[k]then
          -- 0 changes the player's level; 15 preserves it. The same bridge
          -- coordinate can be reached on different levels in one search.
          seen[k]=true;prev[k]={dir=dir,from=key(p[1],p[2],p[3])};q[#q+1]={x,y,elevation}
        end
      end
    end
  end
  return{freeField=freeField,step=step,pathTo=pathTo}
end
return M
