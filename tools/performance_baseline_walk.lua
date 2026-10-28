-- Native input and collision preflight; no teleport across a measured seam.
return function(game, target)
  local U = require("tests.drivers.util")
  local Collision = require("src.world.Collision")
  local Map = require("src.world.Map")
  local Identity = require("src.core.MapIdentity")
  local ow = assert(game.overworld)
  local source = ow.map.id
  local conn = assert(ow.map:connection("north"), "missing native north connection")
  assert(Identity.runtimeId(game.data, conn.map) == Identity.runtimeId(game.data, target),
    "north connection does not lead to the requested scene")
  local dest = assert(game.data.maps[conn.map])
  require("src.world.MapLoader").resolveBlocks(game.data, dest)
  local ts = assert(game.data.tilesets[dest.tileset])
  local cells = math.max(1, math.floor(tonumber(ts.blockCells) or 2))
  local w, h = ow.map.widthCells, ow.map.heightCells
  local function id(x, y) return y*w+x end
  local function goal(x, y)
    return y == 0 and Map.defPassable(dest, ts, x-conn.offset*cells, dest.height*cells-1, false)
  end
  local p = ow.player
  local start,queue,head,prev,how,found
  local waitFrames=0
  -- Moving native NPCs can temporarily occupy a one-cell corridor. Wait for
  -- their real update before replanning; never remove them from collision.
  for attempt=1,17 do
    p=ow.player;start=id(p.cellX,p.cellY)
    queue,head,prev,how,found={start},1,{[start]=-1},{},nil
    local dirs = {{0,-1,"up"},{-1,0,"left"},{1,0,"right"},{0,1,"down"}}
    while head <= #queue do
      local cur = queue[head]; head = head+1
      local x, y = cur%w, math.floor(cur/w)
      if goal(x, y) then found = cur; break end
      for _, d in ipairs(dirs) do
        local nx, ny = x+d[1], y+d[2]
        local key = id(nx, ny)
        local mover = {cellX=x,cellY=y,elevation=ow.map:cellElevation(x,y)}
        if nx>=0 and ny>=0 and nx<w and ny<h and prev[key]==nil
          and Collision.canMove(ow.map,ow.entities,mover,d[3]) then
          prev[key],how[key]=cur,d[3];queue[#queue+1]=key
        end
      end
    end
    if found then break end
    assert(game.stack:active()==ow and not ow.runner:isRunning(),"native scene interrupted route preflight")
    if attempt<17 then U.wait(15);waitFrames=waitFrames+15 end
  end
  if not found then
    local goals,edge={},{};local minY=h
    for x=0,w-1 do if goal(x,0)then goals[#goals+1]=x end end
    for _,key in ipairs(queue)do
      local x,y=key%w,math.floor(key/w);minY=math.min(minY,y)
      if y==0 then edge[#edge+1]=x end
    end
    print('PERF_WALK_NO_PATH '..require('src.link.Json').encode({source=source,target=target,
      start={p.cellX,p.cellY},sourceCells={w,h},destination={dest.width,dest.height},
      cellsPerBlock=cells,offset=conn.offset,reachable=#queue,minReachableY=minY,
      goalColumns=goals,reachableNorthColumns=edge}))
    error('no native collision path to a passable north seam')
  end
  local path, cur = {}, found
  while cur ~= start do
    table.insert(path,1,{x=cur%w,y=math.floor(cur/w),dir=how[cur]})
    cur=prev[cur]
  end
  local report = {source=source,target=target,steps=0,pathCells=#path,crossed=false,preflightWaitFrames=waitFrames}
  for _, step in ipairs(path) do
    assert(game.stack:active()==ow and not ow.runner:isRunning(), "native scene interrupted the planned walk")
    local reached,initiated=false,false
    for _=1,120 do
      p=ow.player
      assert(ow.map.id==source,"left the source before reaching its boundary")
      if p.cellX==step.x and p.cellY==step.y and not p.moving then reached=true;break end
      if p.moving and ((p.targetX==step.x and p.targetY==step.y)
        or (p.cellX==step.x and p.cellY==step.y)) then initiated=true end
      -- A native turn may consume the first press without taking a step.
      -- Hold until the intended step starts, then release before it ends.
      game.input.state[step.dir]=not initiated
      if not initiated then table.insert(game.input.pressQueue,step.dir) end
      U.wait(1)
    end
    game.input.state[step.dir]=false
    assert(reached,"native movement did not reach the next planned cell")
    report.steps=report.steps+1
  end
  for _=1,240 do
    if ow.map.id~=source then
      game.input.state.up=false
      local actual=ow.map.def
      assert(Identity.runtimeId(game.data,ow.map.id)==Identity.runtimeId(game.data,target)
        or (dest.generation==4 and actual.header==dest.header),"walk entered the wrong map")
      report.crossed=true;report.actual=ow.map.id
      report.crossingEnd=love.timer.getTime()
      report.landing={x=ow.player.cellX,y=ow.player.cellY}
      U.wait(30)
      return report
    end
    report.crossingStart=report.crossingStart or love.timer.getTime()
    table.insert(game.input.pressQueue,"up");game.input.state.up=true
    U.wait(1)
  end
  game.input.state.up=false
  error("native north seam did not cross")
end
