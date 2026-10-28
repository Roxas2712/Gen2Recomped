-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local cases=dofile('tests/gen3_trainer_gates/switch_cases.lua')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right','two-trainer-right','two-trainer-right-empty-left'})do
  for _,case in ipairs({'classswitch','classswitch-fainted','classswitch-active','classswitch-string','classswitch-fractional','classswitch-replaced','fresh-other-owner','brainerror'})do
   local row=cases.run('.','gen2',edition,mode,case)
   T.eq(row.selected,true,'actual native controller returns an action')
   if case=='brainerror'or case=='fresh-other-owner'then
    T.eq(row.kind,'move','failed brain/fresh foreign request falls back to a move')
    T.eq(row.move,33,'actual fallback keeps first PP-bearing Tackle')
    T.eq(row.moveSlot,1,'fallback retains its native PP slot')
   else
    local slot=mode=='single'and 2 or mode=='two-trainer-right-empty-left'and 1 or 3
    local original=mode:find('right',1,true)and 2 or 1
    local invalid=case=='classswitch-string'or case=='classswitch-fractional'
    local active=case=='classswitch-active'
    T.eq(row.kind,'switch','registered class selects a native switch')
    T.eq(row.slot,slot,'class selects first available global party slot')
    T.eq(row.executed,true,'actual queued executor completes')
    T.eq(row.occupied,(invalid or active)and original or slot,'execution resolves the exact global slot')
    T.eq(row.replaced,not invalid,'queued slot is not coerced or re-admitted')
    T.eq(row.attackStage,invalid and 4 or 0,'executed switch reconstructs native stages')
    T.eq(row.hp,case=='classswitch-fainted'and 0 or 400,'execution re-reads current party HP')
    T.eq(row.nickname,case=='classswitch-replaced'and'UPDATED_BENCH'or'PROBE','execution re-reads the actual party member')
    T.eq(row.nextSelected,true,'next actual controller decision completes')
    T.eq(row.nextKind,(invalid or active)and'move'or'switch','per-mon class budget follows the actual occupant')
    local nextSlot=false
    if not invalid and not active then nextSlot=(mode=='single'or mode=='double-left')and 1 or 2 end
    T.eq(row.nextSlot,nextSlot,'next class switch follows combined party ownership')
    if not invalid then T.eq(row.partyIndex,active and original or slot,'new battler retains native global party index')end
   end
  end
 end
end
T.finish('native GBA queued trainer switch execution and subsequent decisions')
