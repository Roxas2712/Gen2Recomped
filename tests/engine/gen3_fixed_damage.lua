-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=dofile('tests/gen3_fixed_damage/cases.lua')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','right','right-empty-left'})do
  local rows=C.run('.','gen2',edition,mode)
  T.eq(#rows,220,'all imported native fixed-damage command profiles run')
  for _,row in ipairs(rows)do
   T.eq(row.ok,true,'actual native command executes')
   if row.profile=='normal'then
    local amount=({DRAGON_RAGE=40,SONICBOOM=20,SEISMIC_TOSS=30,NIGHT_SHADE=30,PSYWAVE=row.high and 45 or 15})[row.move]
    T.eq(row.after.hp,400-amount,'numeric imported ID resolves its native fixed amount')
    T.eq(#row.calculations,1,'fixed move uses the public damage seam')
    T.eq(#row.events,1,'fixed move produces a real direct-hit event')
    T.eq(row.history.landed,row.number,'fixed move produces received-hit history')
   elseif row.profile=='zero power'then
    T.eq(row.after.hp,row.before.hp,'zero-power native calculation deals zero')
    T.eq(row.history.landed,false,'zero-power status dispatch produces no received-hit history')
    T.eq(#row.events,0,'zero-power status dispatch produces no damage event')
    T.eq(#row.calculations,0,'zero-power status dispatch skips damage hooks')
    T.eq(#row.rng,0,'zero-power status dispatch skips accuracy and damage draws')
   elseif row.profile=='immunity'or row.profile=='band immune'then T.eq(row.after.hp,row.before.hp,'fixed script respects native type immunity')end
  end
 end
end
T.finish('native numeric imported fixed damage, Psywave and command ownership')
