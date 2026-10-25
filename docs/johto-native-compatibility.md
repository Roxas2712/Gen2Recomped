# Native Johto compatibility checkpoint

## Current focus: VASC on native Gen2

This chat's active development scope is VASC / ASC OMEGA Johto on native
Gen2/Crystal. Origami and Gen3 work belongs to the separate Origami effort.
Unfinished Gen3 canonical-definition changes are preserved on a separate
local WIP branch, outside this active worktree's changes. Gen1 installations
and player profiles remain outside the test scope.

The current development follow-up supplies native movement-state predicates
and resumes forced terrain through the existing mover. The unchanged supplied
camera/control modules now pass 92 CPU integration assertions in both selected
camera modes; the fork passes 328 engine suites and all quick tiers. A subsequent full-package Crystal GPU motion smoke passes on OpenGL and
Metal in both selected modes, including V input and fresh owned-window proofs.
Normal Mart/Center entry/exit and Cherrygrove/Route 29 connection tests now pass
212 assertions and four owned-window proofs per backend in both selected
cameras. Other story transitions, forced-terrain GPU tests and full visuals
remain open. See the
[contract and exact limits](native-gen2-camera-movement.md). The currently
published download/cache fix remains bound to release source `321019ae`.

Apple Silicon now follows the desktop performance policy instead of being
misclassified as a low-end ARM handheld. Fresh full-package Crystal profiles
on OpenGL and Metal use the mod's MEDIUM default; physical NATIVE resolution
and 2X AA are exercised in both selected cameras. See the
[quality measurements and remaining visual limits](native-apple-silicon-quality.md).

A direct read-only compiler probe of the supplied Ver.1.8 package confirms
that both original `VoxelScene` modules compile under the local LuaJIT and
the unchanged bundled LÖVE12 runtime.
Calling the supplied Gen2 structural patch generator on its unchanged Gen2
scene fails compilation: the function starting at generated line 2862 exceeds
60 upvalues at generated line 3273. The probe intercepts compilation before
module execution and does not load the engine or alter mod source. This
establishes that the engine loader does not introduce that compiler failure;
the same error is reproduced in the bundled runtime without a window. Its
executable and Lua framework match the distributed archive. This does not
establish a runtime fix or full renderer acceptance.

The native movement foundation now supplies the four missing terrain queries
behind the existing `src.world.gen2.Permissions` alias. See the
[contract and test scope](native-gen2-movement-permissions.md). Crystal's
complete valid-byte/directional comparison agrees with the separate public
Gen1 reference. Those prerequisite tests alone do not establish the complete `FieldMoves`
action facade or continuous camera movement acceptance.

The native special-movement foundation additionally exposes connection, ledge
and adjacent-boulder handoffs through existing native handlers. The composed
quick suite passes 271 engine suites, three SDK suites and B30. Real CPU actor
interpolation, queues, carpet fades and public boulder completion events pass
549 focused checks. Source/destination side-wall bypasses are fixed on the
shared native paths. See the [handoff contract](native-gen2-movement-handoffs.md)
and [scoped evidence](qa/native-foundation/johto-native-handoffs.json). Those foundation-only results do not by themselves establish the later
continuous-camera or GPU/model acceptance; the newer scoped checkpoint above
records what has subsequently been exercised.

The supplied ASC OMEGA Ver.1.8 package (`3.1.2-omega.1.8`) is the current
read-only test input, superseding the previously tested Ver.1.7. It is tested unmodified with an actual Crystal Rev0 import in separate native-preview
profiles. Full compatibility is **not established**. The Origami port remains
paused; existing Gen1 installations and player profiles are outside this work.

The verified package has 27,329 files. No mod assets, extracted cartridge data,
ROMs or player saves are included in this repository or its releases.

## Desktop file downloads (2026-10-25)

`Fetch.download` now streams through bounded background workers. Its first
poll no longer invokes HTTP or filesystem IO. Worker-side exact-size checks,
staging and atomic publication preserve the prior file before publication is
claimed; a cancellation after that claim is explicitly refused.
The native `mod.fetch` capability record now supplies its actual maximum
response size, activating the supplied VASC downloader's bounded receive path.
The installation-cache adapter also supplies `type = "file"` metadata; without
that field, the real supplied store rejects written chunks as
`cache_write_failed`. Native storage keys, namespaces and error codes remain.

Using the unchanged supplied downloader/store modules with native SDK fetch
and the real `ImportAccess` / `Storage` cache API,
a real HTTPS run downloads `apo.pokemon-hd.g01.dex0141-0151` (24,765,251 bytes),
verifies all 66 files, activates it and restores its journal into a fresh store
instance. No private mod code/assets, source paths or cache contents are shipped.
The source catalog currently supplies eight Gen1 roster packages; that is
content availability, not a restriction to Gen1 gameplay. Native polling peaks
at 0.27 ms in the native-cache LÖVE12 run. This is data-download/activation
acceptance, not in-game menu, private Windows-wrapper, all-package or rendering
acceptance. See [the exact scope and receipt](qa/native-background-download.json).

## Fork integration for testing

The own-fork inbox is integrated separately from upstream review. Existing
battle-command, complete-window capture, item-list/summary and sibling-profile
PR work is combined with this native Gen2 foundation. The composition retains
the newer Gen2 ownership, alias, movement, API-3 and shader-coordinate fixes;
earlier PR snapshots must not roll these back. The audited PR inventory and
validation scope are recorded in
[the integration receipt](qa/fork-inbox-integration.json).
This is an engine test checkpoint, not full VASC/native parity or a new release.
At composed source `5c8e4b8a`, all 324 engine suites, three SDK suites and
all standalone quick tiers pass. The existing public enemy-action consumers
match the pinned reference in 58 comparisons / 116 workers; held-damage
contracts match in four workers, with no differences. These checks use
ROM-free fixtures and establish no additional graphical gameplay acceptance.

## Fixed engine contracts

| Contract | Evidence | Upstream |
| --- | --- | --- |
| Declared `compute` capability | Strict manifest/real loader, 9 checks; supplied package passes discovery | [#197](https://github.com/UNDERdecoded/Gen2Recomped/pull/197) |
| Background `mod.fetch` GET | 14 permission/loader and 12 queue checks; real LÖVE11.5/12 loopback requests; Windows/macOS/Linux transport CI passes | [#199](https://github.com/UNDERdecoded/Gen2Recomped/pull/199) |
| Active-generation method queries | 362 checks; actual Crystal dispatcher now selects Gen2 rather than Gen1 | [#200](https://github.com/UNDERdecoded/Gen2Recomped/pull/200) |
| Observable new-game/continue entry points | 11 native dispatch/recovery checks; actual Gen2 package initialization completes | [#201](https://github.com/UNDERdecoded/Gen2Recomped/pull/201) |
| Public palette row metadata | 19 checks; Crystal GPU window changes from grayscale fallback to colored terrain/buildings | [#202](https://github.com/UNDERdecoded/Gen2Recomped/pull/202) |
| Native map generation/outdoor and phone-service metadata | 256 map and 3,127 phone-service checks; full native Crystal reimport retains all 388 headers including 99 no-service maps | [#205](https://github.com/UNDERdecoded/Gen2Recomped/pull/205) |
| Gen2 collision classes and bounded terrain queries | 525 independent checks; all sampled live cells agree with the native mover in both camera modes on OpenGL/Metal | [#207](https://github.com/UNDERdecoded/Gen2Recomped/pull/207) |
| Native Gen2 directional and special-terrain queries | 264,000 checks independently and in the fork; complete Crystal byte/directional dump matches the pinned public Gen1 reference; continuous controls remain unactivated | [#235](https://github.com/UNDERdecoded/Gen2Recomped/pull/235) |
| Public tileset constant names | 129 independent checks; actual Mart/Center geometry, native grid steps and menus on both backends | [#208](https://github.com/UNDERdecoded/Gen2Recomped/pull/208) |
| Verified native map-source joins | 105 independent checks; encounter, music, scene storage, trainer continuations and deferred scenes follow declared aliases with exact authored overrides | [#211](https://github.com/UNDERdecoded/Gen2Recomped/pull/211) |
| Public environment names and native byte readers | 1,221 independent checks; native bicycle, Dig, spawn and VM policies; all 388 original Crystal map headers retain their grid and event tables | [#213](https://github.com/UNDERdecoded/Gen2Recomped/pull/213), action follow-up in [#94](https://github.com/UNDERdecoded/Gen2Recomped/pull/94) |
| Persistent Gen2 world and menu ownership | 33 ownership and 29 readiness checks; actual V/F6 input and upright menus on OpenGL/Metal | [draft #204](https://github.com/UNDERdecoded/Gen2Recomped/pull/204) |
| Portable scripts and world actions on persistent worlds | 5,290 composed script checks and 2,778 action checks; independent existing branches also pass | Existing [#98](https://github.com/UNDERdecoded/Gen2Recomped/pull/98), [#94](https://github.com/UNDERdecoded/Gen2Recomped/pull/94) updated |
| Live Gen2 battle model and native sprite captures | 306 native checks; real damage, native HP drain, switches and RUN/return in both field-camera entries on OpenGL and Metal | [#223](https://github.com/UNDERdecoded/Gen2Recomped/pull/223) |
| Native Gen2 shared menu chrome | 116 independent checks; unchanged supplied mod installs picture hooks and draws actual sprites | [#224](https://github.com/UNDERdecoded/Gen2Recomped/pull/224) |
| Completed native queue/HP transient retirement | 144 lifecycle and 4,680 auxiliary-hook checks; callback reentry remains blocked and native timing stays unchanged | [#227](https://github.com/UNDERdecoded/Gen2Recomped/pull/227) |

The current full ROM-free quick suite at `8df05832` passes: 264 engine suites,
three SDK suites and B30. Its native clock fixture was updated for the additional startup method;
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

At the phase source, the composed quick suite passes 252 engine suites, three SDK suites and B30.
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

## Development: native coordinate handoff and visit consumption

Source `6ca30e8251127811db74f5203feb3047fef6e9d1` adds `tryCoordScript`
as the actual Gen2 coordinate phase. Native completed steps and deferred or
scripted arrivals dispatch through the same phase. The preceding branch
starts a real compiled coordinate program once on landing and again on its
idle re-ask; this source executes it once for that visit.

Authored replacement events precede the native VM hook; ordinary authored
events follow it. Native saved scenes and the FF wildcard still select the
compiled program. An ineligible scene does not consume a later eligible ask.
Actual cell changes, including a map round trip at identical coordinates,
rearm the visit. A graphics rebuild of the same map does not. New save/data
contexts and a fresh world entry retire old consumption. Running scripts,
overlays, unfinished steps and immediate warp priority remain in force;
directional carpets still admit their native scene events. Reentrant polling
cannot start a second program, and a hook that acquires a real owner or changes
context cannot continue into stale authored events.

All 264 focused checks pass across Gold, Silver, Crystal and Prism, using the
actual VM compiler, ScriptRunner and native Map. The independent #204 branch
also passes these checks and the existing 119 warp, 64 trainer, 110 state,
21 phase, 33 ownership and 29 menu checks. The composed final quick run passes
256 engine suites, three SDK suites and B30.
All 63 hosted GitHub CI checks pass on this production code source.

On this exact source, scoped OpenGL with QA VSync disabled passes native
no-mod New Game, stairs, house exit and menu, and the unmodified supplied
mod's normal home stairs/entry scene/exit, menus and First/Third selection.
The Mart/Center regression passes eight normal transitions, native menus and
both selected modes; only its initial town setup uses teleport. Four fresh
owned-window proofs pass for the home run and four for Mart/Center.
Each run really dispatches one first-floor coordinate program without a
duplicate; fresh owned-window proofs pass. The full continuous camera
controller remains uninstalled. This does not establish all coordinates,
all maps or story completion. Default presentation, Metal and Windows hardware
execution remain open; the published preview is still `ae8359c0`.
See the [source-bound coordinate receipt](qa/native-foundation/johto-native-coordinate-phase.json).

Prepared Windows/macOS QA packages have identical payloads. All 1,025 committed
`src` files match the source except the declared engine-version stamp; the two
relocated preview entry points match their originals. The Windows executable
contains that payload and all eleven DLLs are AMD64; strict macOS signature
verification passes. These packaging checks do not establish Windows gameplay
or publication of these task-owned test artifacts.

## Development: native count and encounter phases

Source `09d3c78f0abc5c9f81ad51940bc4e7661521a7cf` adds native
`countStep` and `tryWildEncounter` phases to the existing Gen2 landing chain.
The order is trainer, warp, coordinate program, count events, then encounter.
Each phase uses the real VM, maps, party and native dispatch; counted visits
cannot double-advance eggs, friendship, poison or either day-care pen.
A pending phone call or expired Repel consumes the footfall before counters.
Egg hatching defers poison presentation, preserving the pending poison count.
Prism and Polished retain their existing counter algorithms. Other generations
retain the original `onStepComplete` return contract.

A negative control against the preceding upstream world branch shows the
Repel-expiry bug: both pens advance and poison removes one HP. The new chain
expires Repel without either advancement or damage. There are 313 focused
CountStep checks; the independently updated #204 passes these plus the existing
coordinate, warp, trainer, state, input/body and menu suites. The composed fork
passes 258 engine suites, three SDK suites and B30. All 63 hosted code checks
pass. The macOS transport job first timed out without diagnostic output, then
passed a single rerun; the initial cause remains unresolved. A local actual
LOVE11.5 loopback transport run also passes.

The importer now retains the complete ROM palette/service byte instead of
losing its high nibble. Native incoming calls and the bike-shop threshold use
that real service gate. Existing masked caches cannot reconstruct the byte,
so stock Gold/Silver/Crystal require native cache revision 9. The supplied
Crystal cartridge was actually reimported through the native importer: all 388
headers are retained, 289 allow phone service and 99 refuse it. Its bytes remain
unchanged. The 3,127-check parser/lowering/serialization/cache/phone suite also
passes on independent #205, alongside its existing 256 metadata checks.

Actual OpenGL with VSync disabled passes no-mod New Game, stairs, house exit
and native menus (14 count calls/14 counter advances). The unchanged supplied
mod passes home traversal and First/Third selection (16/16), and eight normal
Mart/Center transitions in both selected modes (48/48). Eleven fresh owned-window
proofs cover these runs and the actual imported bike-shop call. For the latter,
QA adopts native bike state and restores progress to 1,023; two real input steps
then queue the call at 1,024 and run its actual ROM-derived four-command program
on the following footfall. The phone text appears, no step counters advance
during its ownership, and actual caller/flag cleanup returns control. This is
not a claim that QA manually walked 1,024 bike steps.

Prepared Windows/macOS packages contain the same verified payload. All 1,029
packaged `src` files match committed inputs except the declared engine stamp;
relocated entry points, PE64 executable, eleven AMD64 DLLs and strict macOS
signature checks pass. These artifacts are not published. The existing preview
remains `ae8359c0`; current default/Metal presentation and Windows hardware
execution are still unaccepted. All 132 own open upstream PR heads match pushed
fork branches at this checkpoint.

See the [source-bound count/import/phone receipt](qa/native-foundation/johto-native-count-phase.json).

## Development: retire earlier landing phases

Source `f5f275b27c758e19c19e65c4ff3ce56a4d9e6c5a` prevents native
idle/script-end coordinate polling from running backwards after CountStep or an
encounter query has already consumed that physical visit. This matters when a
phone script changes the saved scene without moving the player: the newly
eligible coordinate program belongs to a later landing, not the just-finished
call. A completed nonmatching encounter roll also retires earlier phases;
calling the public count API afterwards cannot advance counters late.

The new native-VM/phone/counter/real-encounter suite passes 153 checks. Against
preceding independent #204 source `ba87267e`, 36 of the same 153 checks fail.
Current independent #204 head `e602ea72` passes these and all seven existing
focused count/coordinate/warp/trainer/state/input/menu suites, plus 33 world/overlay
ownership checks. Physical movement,
actual save-codec context replacement and eligible retries before a later phase
owns the visit remain valid. The composed quick suite passes 259 engine suites,
three SDK suites and B30; all 63 hosted code checks pass on the exact source.

The current isolated OpenGL build, with QA VSync disabled, also passes actual
Crystal New Game/stairs/exit, the imported bike-shop phone text and cleanup,
and native menu input. The unchanged supplied mod passes home traversal,
entry scene/exit and First/Third selection, plus eight normal Mart/Center door
transitions in both selected modes. Ten fresh owned-window proofs accompany
these runs. These remain native grid-movement regressions; continuous camera
movement and the full generated renderer are not installed. The current Windows
and macOS packages share the verified source payload; Windows hardware and
current default/Metal presentation remain open.

Fork main and upstream main both remain `13af468b`; the working branch includes
that base. All own open upstream PR heads match pushed branches at the recorded
audit. The existing published preview stays `ae8359c0`.

The next concrete encounter work is native `wildoff`/`wildon` (currently VM
no-ops), cave-ice exclusion and the protection interval after battle/warp.
These are open behaviors, not covered by the new landing-phase guarantees.

See the [source-bound retirement receipt](qa/native-foundation/johto-native-landing-retirement.json).

## Development: native encounter gates and entry grace

Source `5b7d630d2d30a431f5cbcf1666f29b5e71486deb` backs the random
encounter phase with native ice/collision eligibility, the actual VM
`wildoff`/`wildon` switch and map-entry/battle-return grace. Cave/dungeon ice
refuses before RNG. The terrain permission chooses the water table independently
of the avatar's surf flag; missing water data cannot reuse cave grass. The
live imported/authored encounter-class list gates route currents. Adopted
non-Gen2 behaviour-byte maps keep their existing meanings.

A five-step counter protects four completed encounter phases and lets the fifth
roll. Physical-visit ownership prevents double decrement. Earlier CountStep
owners, scripts/overlays, moving or out-of-bounds players cannot consume it;
party/wildoff eligibility follows the countdown. Actual map loads, native
battle return and setup/reload commands arm it; graphics-only refresh/reanchor
preserve it. Full map-setup/music/presentation semantics remain separate work.
The wild switch is transient world state and never disables scripted battles.

The new suites pass 281 gate and 420 grace/VM/lifecycle checks. Independent
#204 head `2cf604ff` passes both and all nine existing focused movement/ownership
suites. Preceding `e602ea72` fails 220 gate and 240 grace checks. With the actual
imported Crystal geometry, species, moves and encounter tables, that preceding
code starts a real Swinub battle at an ice cell in Ice Path B1F `(14,28)`. Current
code checks all 677 ice cells in five maps without RNG or battle materialization,
while ordinary floor still constructs a real native Swinub battle/transition.
The composed fork passes 261 engine suites, three SDK suites, B30 and all 63
hosted code checks on the exact source.

Actual isolated OpenGL, with QA VSync disabled, passes a 16-cell native ice slide
ending against a wall; 12 ice footsteps occur after grace reaches zero, all
without encounter RNG or a battle. A two-cell floor route is protected for four
real input steps; the fifth starts a real Swinub battle. The actual command menu
renders, direction input selects RUN, and native BattleState finish/fade/callback
returns to the map with grace 5. Five further input steps with a real compiled
wildoff program do not battle, the switch survives a native warp, and wildon
restores it. QA uses native warps and the native gift command to prepare a
level-100 Cyndaquil test party; normal story progression is not inferred.

The unchanged supplied mod passes the same real 16-cell ice traversal in both
selected First and Third Person modes, plus the floor battle/menu/RUN/return
regression in Third Person. This run uses the mod's public Wilds
`setRandomEncounters` option to enable classic step encounters, then restores
its original value. The default visible-only encounter system is not accepted
by this test: an initial run correctly blocked the underlying native encounter
phase and invalidated the test's countdown assumption. A separate setup attempt
addressed the wrong exported library and failed before applying the option.
Both failed test copies were removed; the final run also removes its verified
27,329-file mod copy. These are native grid and forced-slide checks; continuous
camera-relative movement remains uninstalled. Native and mod runs each have
four fresh owned-window proofs; mixed voxel/native battle proof thresholds are
recorded explicitly.

The mod battle flow passing does not establish correct visuals. Its current
capture has missing Pokemon actors and a level-1/incorrect-HP HUD, while the
actual battle contains level-100 Cyndaquil and level-23 Swinub. The reference
Gen2 screen wraps a separate logic model with live Pokemon in player/enemy;
the fork screen directly holds battler wrappers. A backed data/presentation
bridge needs implementation and live validation. Native no-mod battle visuals
show the correct Pokemon, levels and HP.

Current Windows/macOS QA packages share a verified source payload, with PE64,
eleven AMD64 DLLs, relocated entry points and strict macOS signature checks.
Windows hardware and current default/Metal window acceptance remain open.
At that earlier encounter checkpoint, fork/upstream main were `13af468b` and
the published preview was `ae8359c0`. These historical source statements do not
describe the later download release or current movement development above.

See the [source-bound encounter receipt](qa/native-foundation/johto-native-wild-events.json).

## Open acceptance and concrete failures

- Persistent world ownership is implemented and enables actual camera/menu
  behavior. Broader story, field-action, save and map-lifecycle regressions
  still need acceptance; other generations retain their original stack model.
- Continuous camera-relative movement now installs and passes the scoped CPU
  probe with native state predicates and forced-terrain handoffs, plus a scoped
  full-package Crystal motion/V-input smoke on OpenGL/Metal. Broader GPU
  transitions/forced terrain, story/map/encounter acceptance and complete legacy
  FieldMoves action/fly-picker contracts remain open. Earlier native grid
  walking and boundary tests alone do not cover continuous movement.
- The supplied mod's generated `VoxelScene` patch fails compilation with
  `function ... has more than 60 upvalues`. Its exported
  `rendererInstalled` is false even while the fallback voxel pipeline renders.
  This must not be reported as a complete renderer install.
- The current Third Person Center capture still includes the previously
  recorded black-and-white foreground object. Its cause and full scene
  rendering remain unaccepted.
- The first voxel-character frame reports missing sprite bounds. Later frames
  render; the initial failure and its fallback remain recorded.
- Gen2 PC/mail/box interfaces, follower spawning, battle text/move-menu and
  specialized HP presentation, capture animation and registered-item seams
  are incomplete. Actual native HP values/draining and sprite cards are now
  accepted in the scoped battle loop below.
- The package itself disables overworld capture pending its own ROM QA.
  Engine compatibility cannot turn that disabled feature into a tested one.
- Complete normal doors/warps beyond the tested home/Mart/Center, battles and
  return, all interiors, continuous First/Third Person movement, extended
  sessions and current Windows GPU execution remain open.

Separate QA builds do not themselves publish a release. The release manifest
records the exact packaged source and its scoped verification. No parity
percentage follows from initialization, visible geometry or passing tests.

## Live Gen2 battle data and picture boundary

Source `816126e4` fixes the replacement HUD's level-1/empty-HP fallback. The
shared screen used to publish itself as `battle`, whose `player` and `enemy`
are execution wrappers. Gen2 now publishes a stable read-only model backed by
the actual native Pokemon and party; displayed HP reads the existing native
`stepHPDrain` clock. Switching replaces no copied model or HP animation. The
native picture-capture boundary resolves real front/rear art and retains the
real battler keys for blink, substitute, grow-in and faint effects.

All 304 new native checks pass both in composition and as an independent
patch on upstream main; unchanged main fails the regression. Native timing,
multihit HP and API-3 snapshot regressions pass. The exact composition passes
262 engine suites, three SDK suites and B30. The patch is pushed as
[draft #223](https://github.com/UNDERdecoded/Gen2Recomped/pull/223).

In actual imported Crystal on OpenGL/VSync 0, the unchanged supplied mod now
displays Cyndaquil level 100 with its real 196/196 HP and Swinub level 23.
Two actual wild encounters, one entered from each selected field camera,
reach the native menu, accept physical RUN input and return with five-step
encounter grace. First/Third are selected before entering each fight; V does
not switch the field camera during battle. Native no-mod battle actors/HUD,
RUN and return remain correct. This uses the supported classic random
encounter option and does not accept default visible-only contacts.

**At this earlier source, staged Pokemon actors were absent.** The mod gated
picture-hook installation on the then-missing native Gen2 `Chrome` module.
The subsequent checkpoint below supplies that contract and verifies sprite
cards; the separate generated VoxelScene upvalue limit remains open.
The existing release is unchanged. The [source-bound receipt](qa/native-foundation/johto-native-battle-view.json)
records this partial result and the failed initial camera-test assumption.

## Native chrome, visible battle sprites and corrected package

GPU source `d6149206` includes the real shared Gen2 chrome and the corrected
player-front FX clip window. The unchanged supplied mod now installs its
actual picture hook. Native Cyndaquil/Swinub sprite cards are visible with
correct levels and HP; after the native party menu switches to Totodile, both
the visible actor and HUD follow the actual saved Pokemon. These are native
sprite cards, not acceptance of the separate generated model renderer.

The complete loop passes on OpenGL/VSync 0 and Metal/VSync 1 with Ver.1.7.
The corrected Ver.1.8 also passes on **both OpenGL and Metal with VSync 1**.
Each backend enters an actual native VM-scripted Swinub battle from each
selected First/Third field camera, uses a real QUICK_ATTACK, observes native
damage and HP drain, opens the native party menu, selects the actual second
Pokemon, accepts the opponent's reply, selects RUN and returns to a presented
world. Four fresh owned-window proofs pass once per run. Native input key
edges are injected; OS keyboard hardware is not covered. The proof named
`resized` is a post-switch frame and does not establish resize coverage.

Ver.1.8 was compared by hash across all 27,329 supplied files. Only
`manifest.json` and `gen2/lib/GoldFlyCinematic.lua` differ; the latter anchors
the cinematic on the player when the engine exposes screen offsets rather
than position in `flyAnim`. The flight sequence itself was not exercised by
these battle tests. Supplied sources remain unchanged; each task-owned mod
copy was verified byte-for-byte and removed after its process exited.

Native no-mod ice traversal, random-floor encounter, RUN, VM wild switches
and map return pass on both GPU backends too. In addition, `8df05832` retires
the native queue insertion cursor and completed HP closing hold. Those
markers had prevented the START auxiliary hook from becoming ready again.
The callback still blocks reentrant input, and the original timing and
multihit drains remain unchanged. This separate CPU-tested follow-up passes
144 lifecycle and 4,680 hook checks. The combined suite passes all 264 engine
suites, three SDK suites and B30. GPU evidence remains bound to `d6149206`.

The [sanitized checkpoint](qa/native-foundation/johto-native-battle-chrome.json)
records exact sources, packages, mod versions, damage/switch results and image
hashes. Earlier failed QA assumptions and the unresolved admission of a
battle during one modded ice probe remain recorded; that admission had no
captured caller and is not attributed to the closed native random gate.

The generated Stadium overworld patch still exceeds LuaJIT's 60-upvalue
limit. Complete native text/move-menu/animation contracts, default visible
contacts, continuous movement and full field-move handoffs, PC/mail/box and
follower/capture/registered-item protocols, broader maps/interiors/story/save
and long-session QA remain open. Windows packages pass static verification;
Windows GPU hardware is untested. The existing release remains unchanged.
