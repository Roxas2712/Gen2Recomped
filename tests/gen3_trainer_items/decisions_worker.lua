-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,version,api,format=unpack(arg)
local rows,T=dofile(root..'/tests/gen3_trainer_items/decisions.lua').run(root,backend,version,assert(tonumber(api)),format)
print('GBA_TRAINER_DECISION_PROTOCOL '..require('src.link.Json').encode(rows))
T.finish('GBA trainer decision protocol')
