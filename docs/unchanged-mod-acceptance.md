# Unchanged mod acceptance on both engines

The runtime source from `edfb30feb230d5359540ae6e6fbc33d20dc68b83` passes the
following **selected Red-profile CPU checks** against unchanged Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. No engine or mod production code
was changed for these checks. Graphics, audio and persistence remain doubles.

| Consumer | Gen1 | Gen2 |
| --- | --- | --- |
| Unchanged QoL 1.2.2 native flow | 42/42 | 42/42 |
| Official Battle Art 1.11.2 | 46/46 | 46/46 |
| Battle Art + Legendary Interiors TEST20 | 47/47 | 47/47 |

QoL covers real map entry and banner installation, START/SELECT menus,
strongest-rod selection, B and explicit CANCEL, no-bite dialogue and pose
cleanup, Surf dialogue/transition/landing, an actual Old Rod Magikarp battle,
XP/caught-indicator draw submissions, move PP, experience, victory and return.
Its typed final observation agrees across both engines. Gen1 prints an extra
rod-use message before casting; the test checks the pose during its real
lifetime rather than forcing identical dialogue timing.

Battle Art loads its actual providers alone and with Interiors, switches
Legendary OFF/AUTO/FULL, enters Pallet Town and Oak's Lab through the real
world controller, runs pipeline updates, generates CPU geometry and submits
dedicated room meshes to the room shadow callback. Every generated terrain
vertex and index, and every uploaded room mesh, is checked for valid numeric
data. Pallet's terrain contains 259,216 vertices under OFF and 608,312 under
AUTO/FULL. The lab's dedicated meshes are accounted for separately from its
terrain buffer. Geometry counts and selected typed observations agree across
engines; full vertex-stream or rendered-pixel equality is not claimed.

All four Battle Art cases also run the native world battle transition, intro,
Fight/move selection, Surf attack, victory and return. Each spends one PP and
awards 14 experience. The public staged-battle descriptor yields to the normal
2D battle while graphics-device support is unavailable. This checks fallback
behavior, not a successful staged 3D battle.

The official package SHA-256 values were checked before extraction; source,
package, import and decoded-pixel hashes remained unchanged. Test persistence
stays in memory. No normal saves/imports or Gen1 source/publication changed.

Earlier failed probes remain as negative evidence: missing test-module search
paths, expecting lab meshes in the terrain-only buffer, and incomplete external
mesh/FileData/ImageData/battle-PNG fixtures. Those were repaired in the test
harness, without altering either engine or the published mods. The existing
Gen1 import still logs missing `idEffects` fallbacks for POOF_ANIM/SURF; Gen2
also retains its misleading missing Gen2 fish-group warning on the Red rod path.
These are not visual or animation passes.

Actual shader compilation, material/depth/reflection appearance, free-camera
controls, graphics-device FPS, broader maps, complete mods/playthroughs and
other declared game profiles remain open. The packages declare Gen1 games;
this acceptance does not relabel them as Gold/GBA mods.

See the [compact receipt](qa/unchanged-mod-consumers.json) and
[reproducible consumer probes](qa/consumers/README.md). The earlier full engine
and shared API qualification retains its original source/test refs and scope.
