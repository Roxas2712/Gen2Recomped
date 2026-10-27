-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
function love.conf(t)
  assert(os.getenv('PALETTE_INDEX_QA_GUARDED') == '1', 'use the guarded check.py runner')
  t.identity = assert(os.getenv('POKEPORT_IDENTITY'))
  t.window.width, t.window.height, t.window.vsync = 192, 160, 0
  t.window.highdpi = false
  t.modules.audio, t.modules.joystick, t.modules.physics = false, false, false
  if t.graphics then t.graphics.renderers={os.getenv('POKEPORT_GRAPHICS_BACKEND') or 'opengl'} end
end
