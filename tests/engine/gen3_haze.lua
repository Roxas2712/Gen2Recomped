-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Native=require('src.battle.MoveEffects').RECORDS.HAZE_EFFECT
local originalRun=Native.run
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right','double-right-empty-left','double-left-empty-right'})do
  local rows=dofile('tests/gen3_haze/cases.lua').run('.','gen2',edition,mode)
  T.eq(#rows,15,'native, delegated and authored Haze actions all exercised')
 end
 T.eq(Native.run,originalRun,'shared legacy record remains untouched')
end
for _,edition in ipairs({'red','crystal'})do
 V.set(edition)
 T.eq(require('src.battle.Gen3Haze').builtin('HAZE_EFFECT',Native),Native,'older-generation record is preserved')
 T.eq(require('src.battle.Gen3Builtins').record('HAZE_EFFECT',Native),Native,'older-generation builtin dispatch is preserved')
end
T.finish('native GBA Haze active slots and public effect ownership')
