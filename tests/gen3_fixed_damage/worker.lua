package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode,policy=unpack(arg)
print('GBA_FIXED_DAMAGE '..require('src.link.Json').encode(dofile(root..'/tests/gen3_fixed_damage/cases.lua').run(root,backend,edition,mode,policy)))
