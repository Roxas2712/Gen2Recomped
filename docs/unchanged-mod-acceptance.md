# Unchanged mod acceptance on both engines

The runtime source from `edfb30feb230d5359540ae6e6fbc33d20dc68b83` passes the
following **selected Red-profile CPU checks** against unchanged Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. No engine or mod production code
was changed for these checks. Graphics, audio and persistence remain doubles
for the CPU table below. Subsequent native graphics checks are described separately.

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
harness, without altering either engine or the published mods. The older
Gen1 CPU-fixture import logs missing `idEffects` fallbacks for POOF_ANIM/SURF; Gen2
also retains its misleading missing Gen2 fish-group warning on the Red rod path.
These are not visual or animation passes.

## Selected native graphics acceptance

The unchanged packages also ran in real **LÖVE 11.5 / OpenGL 4.1 Metal on
Apple M2**, using runtime source `2f55f61d98c01b20efbb3c4eecc0eea6808aaf6b`
and the same pinned Gen1 reference. Five completed runs produced **30 PNGs**,
all inspected visually. Each run exited normally with no mod-loader errors.
The earlier source and engine-test tree hashes remain unchanged.

- Both engines compile and use the actual Voxel3D shaders. Selected Pallet
  OFF/AUTO/FULL and Oak's Lab scenes render real terrain, room materials,
  depth and shadows. Optional missing panorama art uses the package fallback.
- First-person movement works in the actual renderer. A verified walkable
  Pallet corridor gives clean first- and third-person views on both engines.
  Doorstep and blocked-cell camera fixtures remain diagnostic evidence.
- Both engines enter the real staged 3D battle, expose a ready public stage
  descriptor, draw the Fight/move menus, execute Surf, win, spend exactly one
  PP, award 14 experience, release the stage and return to the original world.
  The typed battle outcomes agree. Gen2 repeats this with its own regular
  ROM import; it is not dependent on using Gen1's newer export.

These are external scripted scene checks with logical game input, muted audio,
nice 19 and dedicated QA identities. Only frozen source copies receive the
window/stdout instrumentation. Drivers construct new in-memory saves. Gen2's
normal startup migration copied legacy files into its private QA identities;
it does not write back to the originals. Future launches must additionally set
`POKEPORT_SKIP_LEGACY_MIGRATION=1` to avoid inheriting those files at all.
Normal imported inputs and both mod packages remain unchanged. No ROM assets,
third-party mod sources or captured images are distributed with this report.

There are still explicit limits: a missing Red EXP-bar image warning, differing
Gen1 move-menu labels, and no visual certification of Surf animation frames.
The action captures fall between visible text/effect frames. A newer Gen1
export also carries `{PROMPT}` text controls that Gen2 does not strip; the
warning disappears with Gen2's own import. Generated caches are not a shared
interchange format. These results do not certify rendered-pixel identity,
controlled FPS, handhelds, all maps, complete mods/playthroughs or every
Legendary add-on. The tested combination contains Battle Art and Interiors
TEST20; its declared game scope remains Gen1.

The next focused lifecycle gap is `core.quit_to_launcher`: Battle Art registers
cleanup through that Gen1 hook, while the Gen2 runtime does not dispatch it.
It is a quit-decision seam, not a general unload event. A separate change needs
to preserve Gen2's native exit behavior and test the decision/cleanup contract.

See the [native graphics receipt](qa/battleart-graphics.json) for run refs,
capture/log hashes, retained failed fixtures and exact limitations.

See the [compact receipt](qa/unchanged-mod-consumers.json) and
[reproducible consumer probes](qa/consumers/README.md). The earlier full engine
and shared API qualification retains its original source/test refs and scope.
