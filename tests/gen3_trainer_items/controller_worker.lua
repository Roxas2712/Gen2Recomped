-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,version,mode=unpack(arg)
local rows,T=dofile(root..'/tests/gen3_trainer_items/controller.lua').run(root,backend,version,mode)
print('GBA_TRAINER_CONTROLLER '..require('src.link.Json').encode(rows))
T.finish('GBA actual trainer controller and item/switch execution')
