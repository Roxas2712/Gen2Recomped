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

The current full ROM-free quick suite passes: 255 engine suites, three SDK suites and
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

At that earlier checkpoint the interior probe could select both camera modes, but its First Person image
is largely black above a strip of floor. **Interior visuals are not accepted**
from frame counters alone. Map IDs differ from the room profile keys expected by the supplied package.
Tileset names were corrected first. Automatic canonical map names and normal
home traversal are now accepted for the two home rooms, as described below.

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
is evidence of the naming mismatch. At that diagnostic checkpoint native startup and door destinations still used
raw IDs and runtime/storage joins were unfinished. That probe alone did not
establish normal home traversal or complete room/actor presentation. The
automatic startup and normal traversal acceptance below supersede its naming gap.

## Shared physical-map foundation (prior checkpoint)

The foundation checkpoint introduced the explicit `Gen2MapNames.publish` adapter.
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
records that foundation implementation and its tests. Startup was disabled
at that checkpoint. The next section records automatic publication after the
persistent-state, entry/warp and public API consumers were adapted. The
foundation alone was insufficient to fix normal home entry.

## Automatic runtime names and normal home traversal

Committed code `052c71eafc890033cb99377b3067acaf93df16a4` publishes verified
shared map names during actual Data startup, before mods, and reconciles
editor/mod replacements afterward. Incoming native warp requests resolve
through actual shared registry records; original ROM warp tables are retained.
The source maps keep their native addresses and independent authored variants
stay distinct.

Native NPC/item/trainer identities, object visibility, hidden items, scene
state, text pointers, flight visits, blackout spawn and roamers retain their
native save/data keys. Source-first per-leaf reads preserve older public-only
save entries and explicit false values. The bedroom's actual Gen2 PC collision
now opens the personal PC; a Center still opens the general PC. This regression
failed three assertions before the routing fix and passes afterward.

Independent upstream #211 passes 105 source/VM, 260 content-transaction,
23 cache/neighbor and 108 automatic-startup/native-state checks. The independent
reader PR #93 passes its existing 1,041 checks plus 11 physical-alias checks;
#94 passes 2,685 world-action checks. The composed fork passes 250 engine
suites, three SDK suites, B30, 14 physical world/warp checks, 2,792 action
checks and seven package tests. The numeric-environment native-state fixture
follow-up is `5f13ce74`; its production code is identical to the GPU build.

Actual Crystal New Game now reaches `PLAYERS_HOUSE_2F`, takes the normal
stairs to `PLAYERS_HOUSE_1F`, and exits to `NEW_BARK_TOWN` on OpenGL and Metal,
without mods. StartMenu opens/closes after those native warps.

With all 27,329 supplied mod files hash-verified and unmodified, separate
OpenGL and Metal runs start a new game without teleport. Each shows bedroom
and downstairs geometry in the selected First/Third modes, opens/closes the
native menu in each room probe, walks the stairs down/up/down and takes the
normal house exit. Four fresh owned-window proofs per backend show upright
walls, beams, floor and furniture. Native arrival guards remain active: before
returning on a landing staircase the test takes a real collision-valid step
off it, and the engine clears the positional guard itself. It never clears
the guard or assigns player/map positions directly. Initial native scenes are
allowed to release their input owner; this is not complete story acceptance.

The same committed build also repeats normal Cherrygrove Mart/Center entry
and exit in both selected camera modes on OpenGL and Metal: 16 native door
transitions, with StartMenu after every room entry and camera mode retained.
Only the town start position is set by teleport for this regression. Each
backend has four fresh room-window proofs in addition to its four home proofs.
The existing black-and-white Center object and incomplete First-Person avatar
presentation remain visible; they are not marked fixed.

The [sanitized activation receipt](qa/native-foundation/johto-canonical-map-startup.json)
binds these runs to the committed source tree, runtime, unchanged mod manifest,
independent upstream checks and per-file hashes. The tested code head has
63/63 successful hosted CI checks. All 128 open own upstream PR heads were
verified against pushed fork branches at this checkpoint. Windows packages
receive the same source and payload, but Windows GPU execution remains open.

The supplied full generated renderer still fails its 60-upvalue compilation
limit, and these visible scenes use its existing fallback. Selected camera
mode and visible room geometry do not establish complete First/Third avatar
presentation or continuous camera-relative movement.

## Development: native movement state and body/input phases

Source `29e567b6e38765977a62b185d43b702c37e43886` derives Gen2 movement
state from the live player's surf/Pikachu flags and the current save's bike
flag. Low-level state adoption updates those native flags atomically. It does
not keep a second saved state byte, and no player/save means no observed state.

The native actor/scripted-move/input/player/landing block now runs through
`stepBody`; clocks, scene runners and camera follow remain in the outer update.
Actual Gen2 input calls `pollInput` and consumes its world-space `heldDir` in
native terrain/special/player handlers. Suppressing intent does not fall back
to raw keys, and remapping does not rotate it twice. Other generations retain
their input path. Same-tick overlays and battles close movement readiness,
including a menu opened inside the body phase; the world itself on a legacy
stack is not treated as an overlay.

The composed quick suite passes 255 engine suites, three SDK suites and B30.
Independent upstream #204 passes 110 live-state/adoption, 21 input/body/overlay,
33 world-owner and 29 menu-readiness checks. The actor/body test advances a
scripted moving player once and preserves the native actor/input/landing order.
These boundary tests do not establish the complete free-cell landing chain.

No `src.world.gen2.FieldMoves` facade has been advertised or activated yet.
Terrain permissions, character/sprite contracts, native special handoffs and
one authoritative free-cell trainer/warp/coord/step-count/encounter chain
remain open before the supplied continuous camera controls can be accepted.
The phase source above passes real OpenGL native New Game and normal home,
Mart and Center transitions with the unmodified supplied mod, in First/Third
Person, with fresh owned-window proofs. These QA runs explicitly disable
VSync. The default presentation path also stalls on the earlier accepted
source; Metal captures for this new phase source are white and fail the
fresh-frame guard. Neither observation establishes their cause or a successful
Metal regression check. Windows hardware execution remains open. See the
[source-bound phase receipt](qa/native-foundation/johto-native-movement-phases.json).

Follow-up production source `4a84c70e9df23a251e1e463429aed380a16b5b36`
checks real trainer sight at the completed Gen2 landing before later tile work,
retains the no-party/script/overlay gates, and returns the actual approach
verdict. A real activatable staircase under that cell is the competing event.
The same regression across Gold, Silver, Crystal and Prism has 36 failures on
the preceding upstream branch and passes all 64 checks with the fix. Live
player collision and grass readers pass 51 checks; independently #207 passes
its existing 525 collision checks plus these 51. Exact-source GPU acceptance
of this trainer/terrain follow-up is still open. The published release remains
the separately accepted `ae8359c0` composition.

## Development: shared native warp arrival

Source `b6dc1244` extracts the real completed-step warp arrival into
`checkWarpOnArrive`, used by the native step chain as well as integrations.
`clearWarpCooldownIfLeft` and `warpsSuppressed` observe the existing native
arrival cell; there is no parallel cooldown or timer. The guard clears only
when the player leaves that cell. A resolved native warp returns true;
an unresolved dynamic destination returns false without a transition or
backup-state mutation. Gen2 scripts, overlays, active transitions and
unfinished steps retain ownership.

Directional Gen2 carpets remain on native input dispatch rather than becoming
immediate step warps. This preserves coord events on exit mats and prevents
sideways mat traversal from throwing the player outside. The full permission,
special-movement and landing chain is still required before free-cell camera
movement can be enabled.

All 119 focused checks pass across Gold, Silver, Crystal and Prism, including
the real destination resolver, fade midpoint/completion and arrival guard;
only audio output and graphics-dependent map materialization are substituted.
The actual completed-step chain calls the shared arrival phase once and starts
one transition. The independent #204 composition also passes these checks,
64 trainer-priority, 110 state, 21 input/body, 33 ownership and 29 menu checks.
The composed fork passes 255 engine suites, three SDK suites and B30.
Exact-source GPU acceptance and publication of this follow-up remain open;
the published release is still `ae8359c0`.

## Open acceptance and concrete failures

- Persistent world ownership is implemented and enables actual camera/menu
  behavior. Broader story, field-action, save and map-lifecycle regressions
  still need acceptance; other generations retain their original stack model.
- Continuous camera-relative movement is not enabled. Development has live
  native state and consumed input/body phases; the FieldMoves facade, terrain
  permissions and complete shared landing chain remain open. Native grid
  walking and boundary tests do not cover complete continuous movement.
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
- Complete normal doors/warps beyond the tested home/Mart/Center, battles and
  return, all interiors, continuous First/Third Person movement, extended
  sessions and current Windows GPU execution remain open.

Separate QA builds do not themselves publish a release. The release manifest
records the exact packaged source and its scoped verification. No parity
percentage follows from initialization, visible geometry or passing tests.
