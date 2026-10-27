-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Producer protocol through the SDK; complete controller execution is separate.
package.path='./?.lua;./?/init.lua;'..package.path
for _,version in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,policy in ipairs({{1,'native'},{2,'native'},{2,'unified'},{3,'unified'}})do
  local rows=dofile('tests/gen3_trainer_items/decisions.lua').run('.', 'gen2',version,unpack(policy))
  require('tests.modkit').eq(#rows,30,version..' API '..policy[1]..' '..policy[2]..' covers every protocol case')
 end
end
require('tests.modkit').finish('GBA trainer decision producer protocol')
