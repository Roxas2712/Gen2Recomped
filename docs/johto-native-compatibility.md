# Native Johto compatibility checkpoint

The supplied ASC OMEGA Ver.1.7 package (`3.1.2-omega.1.7`) is being tested
unmodified with an actual Crystal Rev0 import in separate native-preview
profiles. Full compatibility is **not established**. The Origami port remains
paused; existing Gen1 installations and player profiles are outside this work.

The verified package has 27,329 files. No mod assets, extracted cartridge data,
ROMs or player saves are included in this repository or its releases.

## Fixed engine contracts

| Contract | Evidence | Upstream |
| --- | --- | --- |
| Declared `compute` capability | Strict manifest/real loader, 9 checks; supplied package passes discovery | [#197](https://github.com/UNDERdecoded/Gen2Recomped/pull/197) |
| Background `mod.fetch` GET | 14 permission/loader and 12 queue checks; real LÖVE11.5/12 loopback requests; Windows/macOS/Linux transport CI passes | [#199](https://github.com/UNDERdecoded/Gen2Recomped/pull/199) |
| Active-generation method queries | 362 checks; actual Crystal dispatcher now selects Gen2 rather than Gen1 | [#200](https://github.com/UNDERdecoded/Gen2Recomped/pull/200) |
| Observable new-game/continue entry points | 11 native dispatch/recovery checks; actual Gen2 package initialization completes | [#201](https://github.com/UNDERdecoded/Gen2Recomped/pull/201) |
| Public palette row metadata | 19 checks; Crystal GPU window changes from grayscale fallback to colored terrain/buildings | [#202](https://github.com/UNDERdecoded/Gen2Recomped/pull/202) |
| Persistent Gen2 world and menu ownership | 33 ownership and 29 readiness checks; actual V/F6 input and upright menus on OpenGL/Metal | [draft #204](https://github.com/UNDERdecoded/Gen2Recomped/pull/204) |
| Portable scripts and world actions on persistent worlds | 5,290 composed script checks and 2,778 action checks; independent existing branches also pass | Existing [#98](https://github.com/UNDERdecoded/Gen2Recomped/pull/98), [#94](https://github.com/UNDERdecoded/Gen2Recomped/pull/94) updated |

The full ROM-free engine/SDK/B30 quick suite passes after the lifecycle change.
The newer palette metadata change also passes its focused main-based test.
These checks do not establish complete gameplay, all maps or Windows GPU
acceptance. HTTP cancellation discards a result immediately; a curl already
executing may occupy its bounded worker until its timeout.

## Actual Crystal checkpoint

The palette correction was first verified at `b0d4dddd`. The subsequent world
ownership/readiness build is source
`c833eb8887decc2d9d0e8ac135f31c098b5be988`, fused with pinned LÖVE12 `937eb3b`. The full supplied package is copied
into each owned profile and verified against the original file hashes before
execution. Only task-owned imported Crystal data is used.

Both OpenGL and Metal now pass real V-key cycling into First Person and F6
switching from First to Third Person. Each mode performs native grid movement
from `(6,7)` to `(7,7)` in New Bark Town. StartMenu opens and closes back to an
empty overlay stack. Four owned-window proofs per backend cover the outdoor
modes, upright menu, and the interior probe. Outdoor and menu images were also
visually inspected. These scenes were set up by teleport; this is not normal
door-traversal acceptance.

The interior probe can select both camera modes, but its First Person image
is largely black above a strip of floor. **Interior visuals are not accepted**
from frame counters alone. Map/tileset metadata differs from the room profile
keys expected by the supplied package and needs investigation.

Additional no-mod runs on OpenGL and Metal complete native New Game, walk
through the bedroom staircase and the house exit into New Bark Town, and open
and close StartMenu. Owned-window captures show the native 2D scene. The
GBC crop has 15 colors, so its blank guard uses a GBC-specific four-color
minimum; the existing GBA/voxel guard retains its 16-color minimum. Identity,
window ownership and fresh-frame checks remain required. Complete story,
all-door and all-map acceptance is not inferred from these two native warps.

The [sanitized receipt](qa/native-foundation/johto-native-compatibility.json)
records exact tested source/runtime, camera phases and the remaining renderer
failures without ROM/mod contents, private paths, process IDs or window IDs.

## Open acceptance and concrete failures

- Persistent world ownership is implemented and enables actual camera/menu
  behavior. Broader story, field-action, save and map-lifecycle regressions
  still need acceptance; other generations retain their original stack model.
- Continuous camera-relative movement lacks the Gen2 `FieldMoves`, `pollInput`
  and `stepBody` contracts. Native grid walking passing does not cover it.
- The supplied mod's generated `VoxelScene` patch fails compilation with
  `function ... has more than 60 upvalues`. Its exported
  `rendererInstalled` is false even while the fallback voxel pipeline renders.
  This must not be reported as a complete renderer install.
- The first voxel-character frame reports missing sprite bounds. Later frames
  render; the initial failure and its fallback remain recorded.
- Gen2 PC/mail/box interfaces, follower spawning, battle HP presentation,
  capture animation and registered-item seams are incomplete.
- The package itself disables overworld capture pending its own ROM QA.
  Engine compatibility cannot turn that disabled feature into a tested one.
- Canonical map/tileset metadata, complete normal doors/warps, battles and
  return, all interiors, continuous First/Third Person movement, extended
  sessions and current Windows GPU execution remain open.

The existing preview release has not been updated to this checkpoint. Its
published source and the separate QA builds must not be conflated. No parity
percentage follows from initialization, visible geometry or passing tests.
