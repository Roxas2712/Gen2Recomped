# Legacy Gen2 mod compatibility

API 1/2 source mods can still target the shared native engine. These adapters
translate their original contracts at the loader boundary; no mod identifier is
special-cased and no second battle controller, wallet or encounter engine runs.

- Source encounter edits during legacy event callbacks update the native
  grass/time, water, tree and fishing records. The derived view remains read-only
  outside that callback scope, including after a throwing callback.
- Authored move/effect vocabulary, level moves and positional move-effect
  callbacks resolve to the actual native move catalogue, battlers and action
  queue. The old combined Special alias reads the actual Sp.Atk value, while
  the native Sp.Atk and Sp.Def remain distinct.
- Legacy Mon creation, OT stamping, evolution, Hall of Fame, phone, money and
  badge queries use the native objects and progress stores.
- Optional local imports do not block save admission. An engine version change
  alone does not imply an unreadable save; incompatible save formats/API levels
  still block with their specific reason. No unknown format is bypassed.
- Old custom 3D mod shaders receive their historical Canvas clip convention on
  LÖVE 12. Standard 2D transforms, native shaders, API 3 and LÖVE 11 retain their
  coordinate contract. This fixes the upside-down player/world seen with legacy
  voxel shaders without editing the supplied renderer mod.

## Validation

The targeted contracts cover content/effects, the native battle model, encounter
views, save admission, imports, launcher requirements, compatibility aliases and
workspace restore. The shader suite loads actual API 2 and API 3 probe mods.

An imported Crystal GPU run with the supplied KASC and VASC packages plus a
separate Mega-only overlay exercises the real native battle and renderer:
logical L activation, authored sphere/sigil/flash, animated Mega front cards,
regular attack damage, victory and return to the map. Player movement and the
upright world/player orientation are also captured. This GPU check uses LÖVE
12.0.0 on macOS; it does not establish other backend/device parity.

KASC's Mega source/art changes remain in its separate private fix repository.
No Mega-specific code or art is included in this engine change. The original
reported save was not available, so it is not covered by the save fixtures.
Full story coverage and every optional legacy mod feature are outside these
checks; optional animation/model assets can still emit their own diagnostics.
