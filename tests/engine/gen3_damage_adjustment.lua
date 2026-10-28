-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=dofile('tests/gen3_damage_adjustment/cases.lua')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 local rs=edition=='ruby'or edition=='sapphire'
 local rows=C.run('.','gen2',edition)
 T.eq(#rows,624,'thirteen actual native moves in all twenty-four profiles and both draw policies')
 for _,row in ipairs(rows)do
  T.eq(row.ok,true,'native action completes')
  if row.profile=='normal'and row.move=='TACKLE'then
   T.eq(row.after.hp,400-(row.high and(rs and 13 or 16)or(rs and 33 or 28)),'native base/critical/variance commands have edition-owned ordering')
   T.eq(#row.calculations,1,'ordinary native damage reaches its public calculation once')
   T.eq(row.calculations[1].deferAdjustment,rs,'only R/S delegates a deferred calculation')
  elseif row.profile=='normal'and row.move=='EXPLOSION'then
   T.eq(row.after.userHP,0,'native Explosion self HP is zero')
   T.eq(row.calculations[1].userHP,0,'public Explosion calculation observes the earlier self-HP command')
  elseif row.profile=='levitate'and row.move=='EXPLOSION'then
   T.eq(row.after.hp,400,'Explosion reaches its native Levitate guard after calculation')
   T.eq(#row.events,0,'immune Explosion produces no HP event')
   T.eq(#row.calculations,1,'Levitate does not hide the pre-accuracy Explosion calculation')
  elseif row.profile=='protect'and row.move=='EXPLOSION'then
   T.eq(row.after.userHP,0,'protected Explosion still self-destructs')
   T.eq(row.after.hp,400,'protected recipient stays unharmed')
   T.eq(#row.calculations,1,'Explosion calculates before protection')
  elseif row.profile=='damp'and row.move=='EXPLOSION'then
   T.eq(row.after.userHP,400,'Damp blocks the self-HP command')
   T.eq(#row.rng,0,'Damp blocks all calculation/accuracy draws')
   T.eq(#row.calculations,0,'Damp blocks the public calculation')
  elseif row.profile=='band sticky'and row.move=='DOUBLE_KICK'then
   T.eq(row.after.hp,rs and 1 or 0,'R/S retains the first Band proc across the later failed roll')
   T.eq(#row.events,2,'both native kicks reach their HP command')
  elseif row.profile=='band sticky later lethal'and row.move=='DOUBLE_KICK'then
   T.eq(row.after.hp,row.high and(rs and 3 or 1)or(rs and 1 or 0),'R/S retains a successful nonlethal Band roll for the later lethal strike')
  elseif row.profile=='endure'and row.move=='SUPER_FANG'then
   T.eq(row.after.hp,rs and 0 or 1,'R/S Super Fang has no damage-adjustment opcode')
  elseif row.profile=='endure substitute'and row.move=='FALSE_SWIPE'then
   T.eq(row.after.substitute,row.high and(rs and 84 or 81)or(rs and 61 or 67),'False Swipe/Endure cannot cap a hit through Substitute')
  elseif row.profile=='miss'and row.move=='JUMP_KICK'and row.high then
   T.eq(row.after.userHP,rs and 387 or 385,'miss crash uses native target-based damage and the edition variance')
   T.eq(#row.calculations,0,'crash never enters the public move-damage hook')
  elseif row.profile=='confused'and not row.high then
   T.eq(row.after.userHP,rs and 387 or 389,'confusion uses its own base and normal2 adjustment')
   T.eq(row.after.hp,400,'self-hit does not touch the selected opponent')
   T.eq(#row.calculations,0,'self-hit never enters the public move-damage hook')
   T.eq(row.after.pp,40,'self-hit cancels before PP reduction')
  elseif row.profile=='normal'and row.move=='ENDEAVOR'then
   T.eq(#row.rng,0,'failed Endeavor skips accuracy and adjustment')
   T.eq(#row.calculations,0,'failed Endeavor skips the damage hook')
  elseif row.profile=='tiny resist'and row.move=='TACKLE'then
   T.eq(row.after.hp,rs and not row.high and 398 or 399,'native low-damage critical rounding matches the selected edition')
   T.eq(#row.events,1,'minimum native damage is a landed hit')
  end
 end
end
T.finish('native edition-owned adjustment, Explosion, crash and confusion action regressions')
