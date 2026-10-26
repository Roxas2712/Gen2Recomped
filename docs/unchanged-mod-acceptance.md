# Unchanged mod acceptance on both engines

The later own-fork integration is recorded in the
[fork-main receipt](qa/fork-main-integration.json). It combines all twenty
functional own-fork PR heads, qualifies 559 engine suites plus four SDK suites
and B30 at the pinned regression ref, and separately checks the subsequent
native Gen2 START/save delta with thirteen affected suites and a real isolated
Crystal save/restart. Twelve GPU runs pass on OpenGL/Metal (4,644 checks,
364 comparisons). The unchanged Battle Art/Legendary prepared-scene run is
pinned separately to its earlier all-PR composition. These observations do
not certify a full playthrough, every mod, exact UI pixels or controlled FPS.
Historical feature receipts below retain their own refs and limitations.

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

## Native quit cleanup

[PR #320](https://github.com/UNDERdecoded/Gen2Recomped/pull/320) adds the missing
`core.quit_to_launcher` decision hook. Qualified combined runtime
`77d0294ce20b83168dfce7461f7854df2d5d3cfb` preserves Gen2's native exit default,
editor veto and worker shutdown, while allowing a mod to request the existing
launcher-return path. It is a quit decision, not a general unload event.

The unchanged Battle Art package, alone and with Interiors, passes **29 checks
per engine across the two configurations** on Gen1, the standalone Gen2 feature
and the combined runtime. Its actual companion is disposed, 11 owned frame
wrappers are removed and repeated cleanup is stable. The previous runtime is
a negative control and fails because it never dispatches the hook.

A further real LÖVE 11.5/OpenGL 4.1 Metal run on Apple M2 renders the FULL voxel
Pallet scene, captures one inspected image, then lets the driver finish so
`main.lua` executes the actual quit path. Cleanup disposes the companion,
reduces its frame wrappers from 12 to one and the process exits zero with no
mod errors. It uses a fresh isolated identity, null audio, nice 19 and disables
legacy migration. Normal inputs and package hashes remain unchanged.

The combined runtime passes **296/296** engine suites, **4/4** SDK suites and
B30. Shared native and unified/API-3 contracts retain identical typed results.
The standalone upstream base still has 11 unrelated pre-existing failing
suites; their failure lines are unchanged. See the
[quit receipt](qa/quit-to-launcher.json) and public consumer probes.

Remaining acceptance includes other profiles/maps/add-ons, complete mod
lifetimes, controlled performance and the animation/UI/data limitations above.
Quit cleanup alone does not certify all GPU-resource disposal or a generic
unload lifecycle.

See the [native graphics receipt](qa/battleart-graphics.json) for run refs,
capture/log hashes, retained failed fixtures and exact limitations.

See the [compact receipt](qa/unchanged-mod-consumers.json) and
[reproducible consumer probes](qa/consumers/README.md). The earlier full engine
and shared API qualification retains its original source/test refs and scope.


## Party-full capture custody

[PR #326](https://github.com/UNDERdecoded/Gen2Recomped/pull/326) adds the missing Gen1 `catch.party_full`
producer. A mod can take responsibility for a catch when the party is full,
without silently depositing it in a PC. Lua truthiness, native false/nil
fallback, dex ownership and the `pokemon.caught` destination match the
reference. The combined runtime also advertises the Gen1 capability and
passes the payload through the shared callback/API-3 layer. Other generations
retain their native storage flow.

The standalone regression passes **410** checks;
the combined regression passes **419**. There
are 36 shared contract workers and **486 complete paired typed rows** across
Red/Blue/Yellow, API 1/2 native and the composed API 2/3 unified modes. On the
original upstream base, 84 new assertions fail; its 11 existing failed suites
have exactly the same 29 old failure lines. Two mutation controls reject a
bypassed call site (84 assertions) and Boolean-only claiming (24 assertions).

Both engines also pass the identical native Red input driver and unchanged
consumer: true/zero mod custody, PC fallback with native nickname `A`, a party
with room and hook unsubscription. Each spends exactly one ball, preserves the
original caught mon and returns to the world. Twelve captures were inspected;
complete typed state results agree. These are functional scene checks, not
rendered-pixel, full-mod/playthrough, controlled-FPS or hardware-audio acceptance.

The qualified runtime passes **300/300 engine suites**, **4/4 SDK suites** and
B30. Inputs remain unchanged, normal profiles are isolated and legacy migration
is disabled. See the [receipt](qa/catch-party-full.json) and public consumer
probes for exact runtime/test refs, hashes and limitations. The mod is
responsible for retaining a claimed catch; the engine does not rescue it later.
