-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right','two-trainer-right','two-trainer-right-empty-left'})do
  local rows=dofile('tests/gen3_trainer_gates/cases.lua').run('.','gen2',edition,mode)
  T.eq(#rows,26,'all native controller gates included')
  for _,row in ipairs(rows)do
   local label=row.label
   local skipped=label=='wild'or label=='pokedude'or label=='oldman'or label=='locked'or label=='recharge'
   local class=label=='class item'or label=='class switch'
   local removed=label=='owner removed'
   local expectedCalls=(skipped or class or removed)and 0 or 1
   T.eq(row.calls,expectedCalls,label..': native lower-seam priority')
   T.eq(row.seamLive,not(label=='owner removed'or label=='owner removed after next'),label..': owner removal reaches the real runtime')
   local brain=label:match('^brain ')and label~='brain after item'
   T.eq(row.brainCalls,brain and 1 or 0,label..': native move-brain phase')
   T.eq(row.brainContext,not not brain,label..': brain receives its native context')
   local expectedStock=label=='wild'or not skipped and not brain and label~='class switch'
   T.eq(row.stock,(expectedStock or label=='brain error after next')and 0 or 13,label..': native stock spending')
   if brain then
    T.eq(row.brainMoves[1].move.id,'TACKLE','first move has its portable identity')
    T.eq(row.brainMoves[2].move.id,'FLY','second move has its portable identity')
    T.eq(row.brainMoves[2].move.effect,155,'move view retains native effect ABI')
    T.eq(row.brainMoves[1].usable,label~='brain error blocked first'and label~='brain error pp depleted','first-slot mask reaches the brain')
    T.eq(row.brainMoves[2].usable,label~='brain blocked','native move mask reaches the brain')
    T.eq(row.move,(label=='brain after seam'or label=='brain table'or label=='brain error pp depleted')and 19 or 33,'brain slot admitted or native fallback selected')
   elseif class then
    T.eq(row.classLeft,0,'class action spends one per-mon use')
    T.eq(row.kind,label=='class switch'and'switch'or'item','native class precedes lower seam')
    if label=='class switch'then
     T.eq(row.slot,mode=='single'and 2 or mode=='two-trainer-right-empty-left'and 1 or 3,'native combined-party class selection')
    end
   elseif label=='recharge'then T.eq(row.kind,'recharge','native recharge execution is retained')
   elseif skipped then T.eq(row.move,33,'forced/tutorial/wild selection stays a move')
   else T.eq(row.kind,'item','ordinary selection uses the native bag')end
  end
 end
end
T.finish('native GBA trainer seam, class and move-brain gates')
