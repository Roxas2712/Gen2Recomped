-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
function love.conf(t)
 t.identity=assert(os.getenv('POKEPORT_IDENTITY'));t.window.width,t.window.height=256,256;t.window.vsync=0;t.window.highdpi=false
 t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
 t.graphics.renderers={assert(os.getenv('POKEPORT_GRAPHICS_BACKEND'))}
end
