-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode,policy=unpack(arg)
local rows=dofile(root..'/tests/gen3_damage_adjustment/cases.lua').run(root,backend,edition,mode,policy)
for _,row in ipairs(dofile(root..'/tests/gen3_damage_adjustment/spread.lua').run(root,backend,edition,mode,policy))do rows[#rows+1]=row end
print('GBA_DAMAGE_ADJUSTMENT '..require('src.link.Json').encode(rows))
