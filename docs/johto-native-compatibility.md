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
| Native map generation/outdoor metadata | 256 independent checks; actual ROM-header classification agrees in Crystal on both backends | [#205](https://github.com/UNDERdecoded/Gen2Recomped/pull/205) |
| Gen2 collision classes and bounded terrain queries | 525 independent checks; all sampled live cells agree with the native mover in both camera modes on OpenGL/Metal | [#207](https://github.com/UNDERdecoded/Gen2Recomped/pull/207) |
| Public tileset constant names | 129 independent checks; actual Mart/Center geometry, native grid steps and menus on both backends | [#208](https://github.com/UNDERdecoded/Gen2Recomped/pull/208) |
| Verified native map-source joins | 105 independent checks; encounter, music, scene storage, trainer continuations and deferred scenes follow declared aliases with exact authored overrides | [#211](https://github.com/UNDERdecoded/Gen2Recomped/pull/211) |
| Public environment names and native byte readers | 1,221 independent checks; native bicycle, Dig, spawn and VM policies; all 388 original Crystal map headers retain their grid and event tables | [#213](https://github.com/UNDERdecoded/Gen2Recomped/pull/213), action follow-up in [#94](https://github.com/UNDERdecoded/Gen2Recomped/pull/94) |
| Persistent Gen2 world and menu ownership | 33 ownership and 29 readiness checks; actual V/F6 input and upright menus on OpenGL/Metal | [draft #204](https://github.com/UNDERdecoded/Gen2Recomped/pull/204) |
| Portable scripts and world actions on persistent worlds | 5,290 composed script checks and 2,778 action checks; independent existing branches also pass | Existing [#98](https://github.com/UNDERdecoded/Gen2Recomped/pull/98), [#94](https://github.com/UNDERdecoded/Gen2Recomped/pull/94) updated |

The full ROM-free quick suite passes: 246 engine suites, three SDK suites and
B30. Its native clock fixture was updated for the additional startup method;
the existing independent logic-speed PR retains all 407 passing assertions.
These checks do not establish complete gameplay, all maps or Windows GPU
acceptance. HTTP cancellation discards a result immediately; a curl already
executing may occupy its bounded worker until its timeout.

## Actual Crystal checkpoint

The palette correction was first verified at `b0d4dddd`; world ownership at
`c833eb8887decc2d9d0e8ac135f31c098b5be988`. The earlier map-metadata/collision
checkpoint is source `cb12d995b2cd51ccc3e19083ae968d386dfe1147`, fused with pinned
LÖVE12 `937eb3b`. The full supplied package is copied
into each owned profile and verified against the original file hashes before
execution. Only task-owned imported Crystal data is used.

Both OpenGL and Metal now pass real V-key cycling into First Person and F6
switching from First to Third Person. Each mode performs native grid movement
from `(6,7)` to `(7,7)` in New Bark Town. StartMenu opens and closes back to an
empty overlay stack. Four owned-window proofs per backend cover the outdoor
modes, upright menu, and the interior probe. Outdoor and menu images were also
visually inspected. These scenes were set up by teleport; this is not normal
door-traversal acceptance.

The actual map definitions now expose generation 2 and the ROM-derived
outdoor flag while retaining map IDs and numeric environment. The tileset
constant aliases described below retain the original family as `sourceTileset`.
The package classifies New Bark Town as `trees` and the home as `interior`.
Across the five phases per backend, all 1,240 sampled cell queries return the
same live COLL_* value and terrain permission as the native mover. Block
changes, boundaries and the separate GBA blocking-bit contract also have
ROM-free coverage. This does not enable the missing continuous movement chain.

The interior probe can select both camera modes, but its First Person image
is largely black above a strip of floor. **Interior visuals are not accepted**
from frame counters alone. Map IDs differ from the room profile keys expected by the supplied package.
Tileset names have since been corrected; canonical map IDs remain open.

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

## Tileset names and two room probes

Source `cb12d995b2cd51ccc3e19083ae968d386dfe1147` publishes named ROM families
under public constants such as `TILESET_POKECENTER`. These are aliases to the
same actual tileset objects; original registry keys, asset/animation IDs and
image paths remain. Map definitions expose that constant and retain their
original family as `sourceTileset`. Map IDs and numeric environments are
unchanged. Authored targets and ambiguous families are not overwritten.

With the unmodified supplied package, Cherrygrove Mart and Pokemon Center
show room geometry, furniture, walls and ceiling lights in First and Third
Person on OpenGL and Metal. Repeated probes use unoccupied native land cells
with a clear aisle, rather than placing the First Person camera directly
against a shelf. Both rooms also pass a native grid step and menu open/close.
Four fresh owned-window captures per backend were recorded, with the scene
geometry visually inspected. These are teleport setups and do not establish
normal door traversal, complete actor/model presentation or all interiors.
Floor/route map-ID spelling still prevents some authored profiles from
matching, including the native home probe above.

The [room receipt](qa/native-foundation/johto-room-tileset-names.json) records
the exact source and scope. Full renderer installation, continuous movement
and broader gameplay remain open.

## Native room doors

Additional runs of the same gameplay source `cb12d995` (all 1,023 packed src
files identical to release source `f56a81f6`) pass four normal entry/exit pairs
per backend: Cherrygrove Mart and Pokemon Center, each in First and Third
Person, on OpenGL and Metal. Only the initial town setup is teleported; the
room doors and exits are reached through native collision-valid movement.
The native menu opens and closes after each entry, and every warp preserves
the selected camera. Four fresh owned-window proofs per backend cover the
entered rooms. The final native map is Cherrygrove City.

The [door receipt](qa/native-foundation/johto-normal-room-doors.json) records
all 16 actual transitions. This is acceptance of those tested native doors,
not all-door/story, continuous movement or post-exit visual acceptance. The
separate home profile/rendering gap remains open.

## Native map sources and environment names

Gameplay source `a96e560449d6430de5aaeb1664132b284fa6995e` adds verified
Gen2 map-source joins and the public environment schema. Encounter tables,
map music and scene values can be read through declared `sourceId` aliases;
exact authored overrides win. Scene writes retain native save keys. This
prepares canonical map identity; it does not globally rename runtime maps.

Gen2 maps now expose `TOWN`, `ROUTE`, `INDOOR`, `CAVE`, `ENVIRONMENT_5`,
`GATE` or `DUNGEON` as `environment`, with the native byte retained as
`environmentId`. Native readers accept both old numeric caches and named
records. The native bicycle, Dig/rope, cave encounters, Flash, gate signs,
blackout spawns and VM environment queries retain their byte semantics.
Authored values and other generations' registries are not converted.

All 388 original map records in the actual Crystal import pass the schema
check without changing native IDs, group/number, block grids, warp or object
tables. Runtime registries additionally contain generated aliases; their
larger record count is not the original cartridge map count.

The same source repeats all 16 native Mart/Center entry and exit transitions
across OpenGL/Metal and both selected camera modes, with menus after entry,
camera preservation and four fresh owned-window proofs per backend. Native
New Game, the bedroom staircase and the house exit also pass without mods on
both backends. Room geometry is visible and upright. A black/white object
remains visible in the Center, and the player avatar can remain visible in the
selected First Person mode. These scenes do not establish complete actor or
First Person presentation. The full renderer and continuous movement remain
unaccepted. Actual V/F6 input, outdoor native grid steps and upright menus
also pass on both backends for this source. The home image still lacks its
room shell and remains visually unaccepted.

The [current schema receipt](qa/native-foundation/johto-environment-schema.json)
records these exact-source regressions and their remaining limits.

## Diagnostic home-ID comparison

Additional runs of the same gameplay source `a96e5604` compare native
`PLAYERS_HOUSE1_F` with existing `PLAYERS_HOUSE_1F` / `PLAYERS_HOUSE_2F`
aliases on OpenGL and Metal. Teleporting through the public native warp path
loads actual Map objects under those names. The native 1F view remains mostly
black above the floor strip; the canonical views draw walls and floors.
Four fresh owned-window proofs per backend record the comparison with the
unmodified mod. No renderer name or profile table was injected. A direct
interior-profile query was unavailable on the exported handle and is not
claimed as evidence.

A subsequent development fix also resolves native trainer continuations and
deferred map-scene dispatch through verified aliases. Its actual VM
registration/compiler/queue regression produces four failures on the previous
code and passes with the fix: 105 total identity checks independently and in
the fork, plus 246 engine suites, three SDK suites and B30. This follow-up is
in upstream #211; the existing published `f0d37ae1` package remains the
previous GPU-verified composition.

The [diagnostic receipt](qa/native-foundation/johto-home-map-alias-probe.json)
is evidence of the naming mismatch. Native startup and door destinations
still use raw IDs; canonical runtime publication and all dependent storage
joins remain unfinished. A visible canonical room does not establish normal
home traversal or complete room/actor presentation.

## Shared physical-map foundation (not activated at startup)

The development branch now has an explicit `Gen2MapNames.publish` adapter.
It joins verified, equal native/normalized/scaffold records into one physical
map while retaining native provenance. Conflicting authored definitions stay
distinct. The maps content registry folds both names through the same address,
including conflict preference, failed-mod rollback, replacement and removal.
A single editor replacement is reconciled; deleted maps are not resurrected.

MapLoader shares one actual Map and GPU owner under those verified physical
aliases. Native/public invalidation, eviction, resident protection and connected
map traversal use that identity. Merely having a similar name or source key
is insufficient; the registry must prove a shared record. Other generations'
registry/cache address spaces retain their behavior.

Tests pass 260 actual content/loader transaction checks and 23 cache/neighbor
checks independently and in the fork; the composed quick suite passes 248
engine suites, three SDK suites and B30. Explicit publication over the actual
Crystal import joins all 214 generated alias addresses in 204 physical
families; 195 original runtime names change. All 388 original block/event
records and native group/number addresses remain intact. The actual compiler
retains 244 trainer continuations and queues the same 34 scene-zero programs
through the new names. These queues are compared without executing the story.

The [source-tree-bound receipt](qa/native-foundation/johto-shared-map-identities.json)
records the exact implementation and tests. **Data startup does not call this
adapter yet.** Persistent state, native entry/warp contexts and API identity
checks must be adapted before automatic publication and fresh GPU acceptance.
This foundation is in upstream #211; it is not part of the currently published
`f0d37ae1` release and does not fix normal home entry by itself.

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
- Canonical map identity, complete normal doors/warps, battles and
  return, all interiors, continuous First/Third Person movement, extended
  sessions and current Windows GPU execution remain open.

Separate QA builds do not themselves publish a release. The release manifest
records the exact packaged source and its scoped verification. No parity
percentage follows from initialization, visible geometry or passing tests.
