-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
for _,version in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right','two-trainer-right','two-trainer-right-empty-left'})do
  local rows=dofile('tests/gen3_trainer_items/controller.lua').run('.', 'gen2',version,mode)
  require('tests.modkit').eq(#rows,16,version..' '..mode..' covers every controller case')
 end
end
require('tests.modkit').finish('GBA actual trainer controller and item/switch execution')
