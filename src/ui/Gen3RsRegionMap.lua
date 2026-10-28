local Kit=require('src.ui.Gen3RsMapKit')
local M={};M.__index=M
function M.available(game,opts)return Kit.available(game)and not(opts and opts.area)end
function M.new(host)
  local kit=Kit.new(host.game)
  local self=setmetatable({host=host,kit=kit},M)
  self.native=kit.load('src.ui.game3.rse.region_map')
  -- Older host saves record visits by map id. Mirror those into the native
  -- flags only in this temporary view, without writing imported save flags.
  kit.visitedFlags={}
  local first=kit.constants:flag('FLAG_VISITED_LITTLEROOT_TOWN')
  for id,visited in pairs(host.game.save.visited or {})do
    local def=host.game.data.maps[id];local section=def and def.regionMapSection
    if (visited==true or visited==1)and section and section>=0 and section<=15 then kit.visitedFlags[first+section]=true end
  end
  self.state=self.native.newState({session=kit.session,mode=host.fly and 'fly' or 'wall',
    mapDef=kit.mapView(host.game.overworld and host.game.overworld.map and host.game.overworld.map.def),
    frameType=(tonumber((host.game.save.options or {}).gen3Frame)or 1)-1,
    onPick=function(section,info)
      local destination=self:destination(section,info.posWithinMapSec)
      assert(destination and destination.map,'Missing native RS fly destination '..section)
      self.closed=true;host.game.stack:pop()
      if host.onFly then host.onFly(destination.map,{map=destination.map,x=destination.x,y=destination.y,nativeRs=true})end
    end,
    onClose=function(picked)if not picked then self.closed=true;host:close()end end})
  self.native.Host._s=self.state;self:sync()
  return self
end
-- Both the actual picker and observations resolve the same native special
-- heal locations (gender, League position and Battle Tower included).
function M:destination(section,pos)
  local destination=self.native.flyWarpDestination(self.kit.session,section,pos)
  if not destination then
    local row=self.native.flyHealLocation(self.state,section,pos)
    destination=row and(self.host.game.data.constants.gen3HealLocations or{})[row.healLocation]
  end
  return destination
end
function M:sync()
  self.host.cx,self.host.cy=self.state.cursorX-1,self.state.cursorY-2
end
function M:update()
  if self.closed then return end
  local input=self.host.game.input;local pressed,held={},{}
  for _,key in ipairs({'up','down','left','right','a','b'})do
    pressed[key]=input:wasPressed(key)or self.pending and self.pending[key];held[key]=input.isDown and input:isDown(key)or pressed[key]
  end
  self.pending=nil
  self.native.frame(self.state,{new=pressed,held=held});if not self.closed then self:sync()end
end
function M:press(key)
  if key=='up'or key=='down'or key=='left'or key=='right'or key=='a'or key=='b'then
    self.pending=self.pending or {};self.pending[key]=true
  end
end
function M:draw()
  local ok,why=require('src.render.GraphicsScope').call(self.native.draw,self.state);if not ok then error(why,0)end
end
function M:exit()self.closed=true;self.native.reset()end
return M
