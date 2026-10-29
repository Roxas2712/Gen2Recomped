function love.conf(t)
 t.identity=assert(os.getenv('QA_BOTTLENECK_IDENTITY'))
 assert(t.identity:match('^oasc%-gen2recomp%-qa%-recorder%-'))
 t.window=false;t.modules.audio=false;t.modules.graphics=false
 t.modules.joystick=false;t.modules.physics=false;t.modules.video=false
end
