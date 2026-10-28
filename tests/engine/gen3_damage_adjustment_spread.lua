-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=dofile('tests/gen3_damage_adjustment/spread.lua')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','right','right-empty-left'})do
  for _,called in ipairs({false,true})do
   local rows=S.run('.','gen2',edition,mode,'delegate',called)
   T.eq(#rows,24,'all Explosion field/body profiles execute')
   local expected=mode=='single'and 1 or mode=='right'and 3 or 2
   local user=mode=='single'and 1 or 3
   for _,row in ipairs(rows)do
    T.eq(row.pp,39,'direct/called multi-target action reduces learned PP once')
    if row.profile=='spread normal'or row.profile=='spread Damp after first'then
     T.eq(#row.calculations,expected,'every native target gets its own pre-accuracy calculation')
     T.eq(#row.events,expected,'one reached body for every living native recipient')
     T.eq(row.after[user].hp,0,'Explosion self-HP command survives direct and native caller ownership')
     for _,calc in ipairs(row.calculations)do T.eq(calc.userHP,0,'all targets calculate after the native self-HP command')end
    elseif row.profile=='spread protect all'then
     T.eq(#row.calculations,expected,'protected targets still reach Explosion calculation')
     T.eq(#row.events,0,'protected targets produce no HP event')
     T.eq(row.after[user].hp,0,'protection never suppresses Explosion self faint')
    elseif row.profile=='spread Damp ally'or row.profile=='spread Damp user'or row.profile=='spread Damp foe'then
     T.eq(#row.calculations,0,'any present Damp blocks the entire direct/called spread script')
     T.eq(#row.events,0,'Damp cannot leave a later spread body running')
     T.eq(row.after[user].hp,400,'Damp leaves the user alive')
    elseif row.profile=='spread immune first'then
     T.eq(#row.calculations,expected,'immune first body cannot stop later calculations')
     T.eq(#row.events,expected-1,'later targets are still damaged after first immunity')
    end
   end
  end
 end
end
T.finish('native direct and actual Metronome-called Explosion target ownership, Damp and protection')
