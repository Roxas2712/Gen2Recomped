-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=dofile('tests/gen3_hit_history/cases.lua')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','left','right','right-empty-left'})do
  local rows=C.run('.','gen2',edition,mode)
  T.eq(#rows,27,'actual command history profiles complete')
  for _,row in ipairs(rows)do
   T.check(#row.history>=2,'initial and final observations exist')
   if row.case=='normal' then
    T.eq(#row.events,1,'one actual direct-hit event')
    T.eq(row.events[1].history.landed,false,'landed move is published after damage_dealt')
    T.eq(row.events[1].history.attacker,mode=='right'and 2 or 0,'HP attacker is published before damage_dealt')
   end
  end
 end
end
T.finish('native hit history actual producers, event ordering and effective move views')
