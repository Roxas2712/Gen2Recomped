-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
function love.conf(t)
 t.identity=assert(os.getenv('INSTALL_QA_IDENTITY'))
 assert(t.identity:match('^oasc%-mod%-installer%-qa%-%x+$'),'owned QA identity required')
 t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.sound=false
end
