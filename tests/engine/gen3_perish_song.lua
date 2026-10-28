-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local suite=dofile('tests/gen3_perish/cases.lua')
local T=require('tests.modkit')
local Native=require('src.battle.MoveEffects').RECORDS.PERISH_SONG_EFFECT
local original=Native.run
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double','empty-left','empty-right'})do
  local native=suite.run('.','gen2',edition,mode,'native')
  local delegated=suite.run('.','gen2',edition,mode,'delegate')
  local authored=suite.run('.','gen2',edition,mode,'override')
  T.same(delegated,native,'public delegation retains native effect and residual snapshots')
  T.eq(#authored,5,'all authored override controls are exercised')
 end
 T.eq(Native.run,original,'legacy effect record is never mutated')
end
for _,edition in ipairs({'red','crystal'})do
 require('src.core.GameVersion').set(edition)
 T.eq(require('src.battle.Gen3PerishSong').builtin('PERISH_SONG_EFFECT',Native),Native,'older generation record stays unchanged')
 T.eq(require('src.battle.Gen3Builtins').record('PERISH_SONG_EFFECT',Native),Native,'older generation builtin dispatch stays unchanged')
end
T.finish('native Perish Song public effect ownership and generation guards')
