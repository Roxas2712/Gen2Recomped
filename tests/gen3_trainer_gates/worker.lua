-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
local rows,T=dofile(root..'/tests/gen3_trainer_gates/cases.lua').run(root,backend,edition,mode)
print('GBA_TRAINER_GATES '..require('src.link.Json').encode(rows))
T.finish('native GBA trainer controller gates')
