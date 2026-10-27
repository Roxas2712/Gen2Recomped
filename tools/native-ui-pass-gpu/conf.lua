function love.conf(t)
 t.identity=assert(os.getenv('POKEPORT_IDENTITY'))
 t.version='12.0';t.window.width=320;t.window.height=240
 t.window.visible=true;t.window.vsync=0;t.window.msaa=0
 t.graphics.renderers={assert(os.getenv('POKEPORT_GRAPHICS_BACKEND'))}
 t.modules.audio=false;t.modules.joystick=false;t.modules.physics=false
end
