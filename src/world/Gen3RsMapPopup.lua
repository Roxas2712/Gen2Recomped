local Kit=require('src.ui.Gen3RsMapKit')
local M={};M.__index=M;M.available=Kit.available
function M.new(game)
  local kit=Kit.new(game)
  return setmetatable({kit=kit,data=game.data,save=game.save,version=require('src.core.GameVersion').get(),
    native=kit.load('src.ui.game3.rs.map_name_popup')},M)
end
function M:matches(game)
  return self.data==game.data and self.save==game.save and self.version==require('src.core.GameVersion').get()
end
function M:show(def)return self.native.show(self.kit.mapView(def))end
function M:reset()self.native.dismiss()end
function M:tick()self.native.frame();return self.native.task~=nil end
function M:draw()
  local ok,why=require('src.render.GraphicsScope').call(self.native.draw);if not ok then error(why,0)end
end
return M
