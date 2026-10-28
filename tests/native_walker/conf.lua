-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
function love.conf(t)
 t.identity=assert(os.getenv('POKEPORT_IDENTITY'));t.version='12.0'
 t.window=false;t.modules.audio=false;t.modules.physics=false
end
