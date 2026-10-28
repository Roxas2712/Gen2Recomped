-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
local rows,T=dofile(root..'/tests/gen3_mist/cases.lua').run(root,backend,edition,mode)
print('GBA_MIST_CONTRACT '..require('src.link.Json').encode(rows))
T.finish('native GBA Mist side effects and continuation')
