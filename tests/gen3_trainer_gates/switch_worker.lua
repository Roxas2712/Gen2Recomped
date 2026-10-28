-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode,case=unpack(arg)
local suite=dofile(root..'/tests/gen3_trainer_gates/switch_cases.lua')
local rows={}
for _,name in ipairs(case and{case}or{'classswitch','classswitch-fainted','classswitch-active','classswitch-string','classswitch-fractional','classswitch-replaced','fresh-other-owner','brainerror'})do
 rows[#rows+1]=suite.run(root,backend,edition,mode,name)
end
print('GBA_TRAINER_SWITCH '..require('src.link.Json').encode(rows))
require('tests.modkit').finish('native queued trainer switch execution')
