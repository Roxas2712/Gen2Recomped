-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Legacy Gen1 effect-registration contract. Source mods could add effects
-- absent from their host; a later shared engine must not reserve those names
-- retroactively. Real duplicates and native/unified API registrations remain
-- strict. No mod id is special-cased.
-- Source catalogue: Gen1Recomp 50947eec2aa0404f71b2b105bba837e3629e0cb6
-- src/battle/MoveEffects.lua SHA256 3890101ca7236a8d777b7ad5f0528a0ed45f67caa836e91b8558ff0b3c2bc1db
local original={
  ACCURACY_DOWN1_EFFECT=true,
  ATTACK_DOWN1_EFFECT=true,
  ATTACK_DOWN_SIDE_EFFECT=true,
  ATTACK_TWICE_EFFECT=true,
  ATTACK_UP1_EFFECT=true,
  ATTACK_UP2_EFFECT=true,
  BIDE_EFFECT=true,
  BURN_SIDE_EFFECT1=true,
  BURN_SIDE_EFFECT2=true,
  CHARGE_EFFECT=true,
  CONFUSION_EFFECT=true,
  CONFUSION_SIDE_EFFECT=true,
  CONVERSION_EFFECT=true,
  DEFENSE_DOWN1_EFFECT=true,
  DEFENSE_DOWN2_EFFECT=true,
  DEFENSE_DOWN_SIDE_EFFECT=true,
  DEFENSE_UP1_EFFECT=true,
  DEFENSE_UP2_EFFECT=true,
  DISABLE_EFFECT=true,
  DRAIN_HP_EFFECT=true,
  DREAM_EATER_EFFECT=true,
  EVASION_UP1_EFFECT=true,
  EXPLODE_EFFECT=true,
  FLINCH_SIDE_EFFECT1=true,
  FLINCH_SIDE_EFFECT2=true,
  FLY_EFFECT=true,
  FOCUS_ENERGY_EFFECT=true,
  FREEZE_SIDE_EFFECT1=true,
  HAZE_EFFECT=true,
  HEAL_EFFECT=true,
  HYPER_BEAM_EFFECT=true,
  JUMP_KICK_EFFECT=true,
  LEECH_SEED_EFFECT=true,
  LIGHT_SCREEN_EFFECT=true,
  METRONOME_EFFECT=true,
  MIMIC_EFFECT=true,
  MIRROR_MOVE_EFFECT=true,
  MIST_EFFECT=true,
  NO_ADDITIONAL_EFFECT=true,
  OHKO_EFFECT=true,
  PARALYZE_EFFECT=true,
  PARALYZE_SIDE_EFFECT1=true,
  PARALYZE_SIDE_EFFECT2=true,
  PAY_DAY_EFFECT=true,
  POISON_EFFECT=true,
  POISON_SIDE_EFFECT1=true,
  POISON_SIDE_EFFECT2=true,
  RAGE_EFFECT=true,
  RECOIL_EFFECT=true,
  REFLECT_EFFECT=true,
  SLEEP_EFFECT=true,
  SPECIAL_DAMAGE_EFFECT=true,
  SPECIAL_DOWN_SIDE_EFFECT=true,
  SPECIAL_UP1_EFFECT=true,
  SPECIAL_UP2_EFFECT=true,
  SPEED_DOWN1_EFFECT=true,
  SPEED_DOWN_SIDE_EFFECT=true,
  SPEED_UP2_EFFECT=true,
  SPLASH_EFFECT=true,
  SUBSTITUTE_EFFECT=true,
  SUPER_FANG_EFFECT=true,
  SWIFT_EFFECT=true,
  SWITCH_AND_TELEPORT_EFFECT=true,
  THRASH_PETAL_DANCE_EFFECT=true,
  TRANSFORM_EFFECT=true,
  TRAPPING_EFFECT=true,
  TWINEEDLE_EFFECT=true,
  TWO_TO_FIVE_ATTACKS_EFFECT=true,
}
local M={}
function M.canRegister(loader,registry,mod,id)
  local manifest=mod.manifest
  return (manifest.api or 1)<3 and manifest.content_format~='unified'
    and loader:_generation()==1 and registry.name=='move_effects'
    and not original[id] and registry.owners[id]=='engine'
end
return M
