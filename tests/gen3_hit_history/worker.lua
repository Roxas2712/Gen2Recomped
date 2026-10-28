package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
print('GBA_HIT_HISTORY '..require('src.link.Json').encode(dofile(root..'/tests/gen3_hit_history/cases.lua').run(root,backend,edition,mode)))
