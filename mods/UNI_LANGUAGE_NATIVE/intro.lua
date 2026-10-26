-- Shared Ascendant artwork, shown once per mod data directory (all editions).
-- A stable marker survives language changes and mod updates. Interrupted or
-- failed loads do not consume it; completed and explicitly skipped intros do.
local M={marker='preferences/ascendant-intro-v1.txt'}
function M.pending(mod,preferences) return (preferences or mod.cache):read(M.marker)~='seen' end
function M.new(mod,own,finished,preferences)
 local Scene=own('intro/IntroScene.lua')
 local scene=Scene.new(function(path)return mod:read('intro/'..path)end)
 local self={elapsed=0,duration=scene.duration,drawn=false,closed=false}
 local paused={}
 if love.audio and love.audio.pause then
  local ok,sources=pcall(love.audio.pause)
  if ok and type(sources)=='table' then paused=sources end
 end
 local function release()
  if self.closed then return end
  self.closed=true;scene:release();scene=nil
  for _,source in ipairs(paused) do pcall(function()source:play()end) end
  paused={}
 end
 function self:close() release() end
 local function complete()
  if self.closed then return end
  local ok,err=(preferences or mod.cache):write(M.marker,'seen')
  if not ok then mod.log:warn('Could not save Ascendant intro completion: %s',tostring(err)) end
  finished();release()
 end
 function self:skip()
  if self.drawn and self.elapsed>=.2 then complete();return true end
  return false
 end
 function self:update(dt)
  if self.closed or not self.drawn then return end
  self.elapsed=self.elapsed+math.max(0,math.min(dt,.1))
  if self.elapsed>=self.duration then complete() end
 end
 function self:draw()
  if self.closed then return end
  if not self.drawn then
   local opts=mod.game.options or {}
   scene:play(opts.splashMute and 0 or 1);self.drawn=true
  end
  scene:draw(self.elapsed,love.graphics.getDimensions())
 end
 return self
end
return M
