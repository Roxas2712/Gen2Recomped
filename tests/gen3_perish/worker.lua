-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
local rows=dofile(root..'/tests/gen3_perish/cases.lua').run(root,backend,edition,mode)
print('GBA_PERISH_CONTRACT '..require('src.link.Json').encode(rows))
require('tests.modkit').finish('native Perish Song effect and residual contract')
