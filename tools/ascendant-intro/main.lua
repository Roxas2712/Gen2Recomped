-- Shared Ascendant animation; prelude integration by Roxas2712.
local scene,elapsed,started= nil,0,false
local fixed=tonumber(os.getenv('ASCENDANT_QA_FRAME'))
local function read(path)
 if path:sub(1,7)=='assets/' then
  local root=assert(os.getenv('ASCENDANT_ASSETS'),'Ascendant asset directory missing')
  local file=assert(io.open(root..'/'..path:sub(8),'rb'));local bytes=file:read('*a');file:close();return bytes
 end
 return love.filesystem.read(path)
end
function love.load()
 scene=require('IntroScene').new(read)
 love.graphics.setBackgroundColor(0,0,0)
end
function love.update(dt)
 if not started then
  if love.window.isVisible() then started=true;scene:play(fixed and 0 or .7) end
  return
 end
 if fixed then elapsed=fixed;return end
 elapsed=elapsed+math.min(dt,.1)
 if elapsed>=scene.duration then love.event.quit(0) end
end
function love.draw()
 scene:draw(elapsed,love.graphics.getDimensions())
end
function love.keypressed(key) if not fixed or key=='escape' then love.event.quit(0) end end
function love.mousepressed() if not fixed then love.event.quit(0) end end
function love.gamepadpressed() love.event.quit(0) end
function love.quit() if scene then scene:release() end end
