-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local names=dofile('tests/gen3_trainer_types/imported.lua').names
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right','two-trainer-right','two-trainer-right-empty-left'})do
  local rows=dofile('tests/gen3_trainer_types/cases.lua').run('.','gen2',edition,mode)
  T.eq(#rows,60,'six encodings cover all types and the observed alias decision')
  for _,row in ipairs(rows)do
   local expected
   for slot,entry in ipairs(row.moves)do
    local number=row.numbers[slot];local kind=(number-200)%18
    local category=number>=218 and'status'or(kind<=8 and'physical'or'special')
    T.eq(entry.slot,slot,'native PP slot retained')
    T.eq(entry.move.index,number,'native move number retained')
    T.eq(entry.move.type,names[kind],'portable canonical type name')
    T.eq(entry.move.gen3Type,kind,'native type number retained, including zero')
    T.eq(entry.move.category,category,'GBA category follows power and native type')
    T.eq(entry.usable,not(row.blocked and slot==1),'native slot mask retained')
    if not expected and entry.usable and category=='physical'then expected=number end
   end
   if not expected then
    for _,entry in ipairs(row.moves)do if entry.usable and entry.move.category=='status'then expected=entry.move.index;break end end
   end
   if not expected then for _,entry in ipairs(row.moves)do if entry.usable then expected=entry.move.index;break end end end
   T.eq(row.chosen,expected,'public brain makes its native category-based decision')
  end
 end
end
T.finish('native trainer-brain canonical move types from real importer stages')
