-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
-- Gen1's GBA builtin lives in its owned effect engine, not mod.content.
-- Compare actual native actions here; host public delegation has its own suite.
local rows,T=dofile(root..'/tests/gen3_haze/cases.lua').run(root,backend,edition,mode,{'native'})
print('GBA_HAZE_CONTRACT '..require('src.link.Json').encode(rows))
T.finish('native GBA Haze action')
