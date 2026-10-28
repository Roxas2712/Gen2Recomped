-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode,control=unpack(arg)
print('GEN3_FAINT_FRIENDSHIP '..require('src.link.Json').encode(dofile(root..'/tests/gen3_faint_friendship/cases.lua').run(root,backend,edition,mode,control=='disable-owner')))
