assert(love.filesystem.load('tools/windows-demo/original-conf.lua'))()
local configure=love.conf
function love.conf(t)
 configure(t)
 t.identity=require('tools.windows-demo.Profile').BOOTSTRAP
 t.window.title='RetroRecomped · Windows Demo · 20261030.3'
 if os.getenv('RETRO_WINDOWS_CLOUD_SELFTEST')=='1'then
  t.identity='oasc-windows-cloud-qa-'..os.time()
  t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.joystick=false;t.modules.physics=false
 end
end
