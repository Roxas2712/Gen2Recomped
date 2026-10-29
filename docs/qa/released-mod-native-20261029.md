# Unchanged published mods: native compatibility investigation

This is development-source evidence, not a release or complete-mod acceptance.
Only the engine was changed. Published ZIPs and their installed files were
compared byte for byte; the ROMs and the earned private QA checkpoint were
unchanged. Protected Gen1 and player instances were not used as test hosts.

## Actual Crystal result

Source `92ea26df90f1701ea6601b3fb1041d12680cf938`, including main `42ff9dec`,
ran on LÖVE12 Metal / Apple M3 with the published
[Battle Art Gen2 2.1.4](https://github.com/absol89/Gen2Recomped-DramaticShapes/releases/tag/2.1.4)
and [Gen1Follower 1.8.0](https://github.com/wild1walker/Gen1Follower/releases/tag/v1.8.0).

- The native installer installed both releases, and the loader reported no mod
  errors. All 178 Battle Art and 423 Follower files matched their ZIP members.
- Normal title/CONTINUE input loaded the earned Cyndaquil checkpoint in Elm's
  lab. Native world updates remained active throughout the test.
- The normal display key selected the mod's voxel pipeline. Eight map palettes
  reached the unchanged Gen2 adapter. Two real OS captures showed upright,
  colored furniture and wall details, with the actual companion behind the player.
- Normal START/Pokémon input opened the native party submenu and its FOLLOWER
  entry. Normal left movement moved the player from `(5,3)` to `(3,3)` while
  the same companion actor followed, using the published `follower_155.png`.
- Normal display-key cycling selected First Person (level6) and Third Person
  (level7). Both scene-ready flags and two actual OS captures per view were
  checked. This proves selection/rendering in this room, not movement in those
  modes or outdoor/cross-map acceptance.

Eight OS captures were reviewed over four phases (field, party submenu, First
Person, Third Person), with advancing native draw counters. The driver and
native child exited successfully. Complete mod acceptance remains false.

Visual limitations remain: the party HP fill appeared gray, and the close Third
Person framing partly cropped the follower. These observations are not yet
attributed to an engine defect. No claim of Gen1 visual parity follows from this
room test.

## Engine findings addressed

1. The Gen2 adapter requires `world.palettes` before calling `Palettes.bgSet`.
   The native world now exposes Data's live, owner-bound `gen2Palettes` view.
   Dataset replacement and authored raw fields retain their normal behavior;
   no copied palette cache or mod-specific palette constant is introduced.
2. The adapter's title precache world is a plain data table with `tilesets` and
   `atlasFor`. Native `atlasFor` now admits that supplied table without requiring
   all live-world methods. Current/neighbor tilesets retain priority, raw atlas
   semantics remain unchanged, and custom Gen3 descriptor dispatch is retained.
3. Gen1Follower imports shared `src.world.PikachuFollower` even on Gen2. Its
   named predicate setter previously existed only through `gen2.Follower`.
   The shared controller now resolves the same native setter on the current
   Gen2 edition. Gen1's existing native/shim contract and Gen3 owner remain
   unchanged. The initial real test showing a menu entry but no follower was
   preserved as a failed test, then repeated successfully after this correction.

These follow the collector's earlier display-key/pipeline gate, NPC rebuild and
sprite-definition, shader-entry precision, and verified producer-orientation
changes. No mod entry, manifest or function was rewritten.

## Scoped regression evidence

Frozen source `ee72c716` passed 1,276 assertions in seven suites:
`gen2_world_palettes` (31), `gen2_atlas_consumer` (30),
`gen2_palette_context` (348), `gen2_people_sprites` (182), `api3_npc` (419),
`legacy_npc_controls` (152), and `gen2_alias_world_reads` (14).

Frozen source `92ea26df` passed another four relevant suites:
`gen2_follower_predicate` (322), `follower_spawn` (3,238),
`native_follower_callback_owner` (12), and `gen3_follower_owner` (13).
The actual loader tests cover both import routes, mod unloading and failed-entry
rollback; native follower tests retain Gen1/Gen3 behavior.

On earlier combined source `6e05037e`, the actual LÖVE12 shader-entry GPU contract
passed 192 asymmetric-pixel/discard checks each on Metal and OpenGL. Raw
lowp/mediump entries failed Metal's precision check; the engine-adapted variants
compiled, validated and produced the expected pixels. This is synthetic GPU
evidence, not a complete third-party-mod pass.

## Yellow and remaining acceptance

On source `92ea26df`, a separate new Yellow journey installed and loaded
Battle Art Voxel Fork1.11.2, Legendary Interiors0.20.0, Legendary 3D NPCs1.1.6-test16,
and Legendary Battle Free Orbit0.1.0-test4 unchanged. All 1,347 installed files
matched their published ZIP members. Normal intro/naming input reached the field;
an actual OS observation showed a textured, upright Legendary bedroom with
furniture, plants, lighting/shadows and the native player. LÖVE deprecation
warnings remained visible in that development window.

The mandatory disk-reserve guard then stopped the Yellow job. Its receipt was
recovered from surviving driver/source metadata, file comparisons and terminal
output; the exact child exit code was not recorded. It is **not a passed run**.
The guarded starter's private exception cleanup was corrected to reap a stopped
child and retain the failure receipt without resuming past the guard.

Still required before complete acceptance or merge: current-head full CI and
combined-main qualification; native battles and their HUD/camera; actual 3D NPC
interaction; connected-map/outdoor traversal; save/restart; the separate
Legendary host alternative; standalone battle-UI and follower combinations.
Windows and packaged-release acceptance are not established by these macOS tests.

## Native battle follow-up

The exact tree of source `95e265b16b60ca2ce96f87d033df26b41ec33cc8` passed
the official full CI: 984/984 engine suites, 4/4 SDK suites, and all available
ROM-free tiers in run 40898996522. This includes the corrected plain-session
`Game.keypressed(session, key)` dispatch; the original battle color/music
regression remains unchanged. The separate macOS download-transport job was
cancelled twice before receiving a runner (`runner_name` empty, no steps or
logs). Its Linux and Windows jobs passed. This is not full platform acceptance.

A current-source Crystal journey left Elm's lab, walked in Third Person through
New Bark to Route29 over the real connection, and displayed the First Person
exterior in two advancing OS captures. The initial straight grass sweep stalled
against the legitimate imported actor at `(50,12)`; it did not represent hundreds
of completed steps. The driver now uses native collision/NPC path planning to
walk around that actor. No encounter rule or RNG was changed.

A subsequent unchanged-mod run reached a natural wild battle, won through normal
command input, awarded Cyndaquil EXP135→150 (HP19→15), and returned to the upright
3D route. Its actual battle window was white except for party-ball slots despite
a ready 2048×1536 staged canvas. Independent OS review therefore failed the run;
the raw functional-only receipt is preserved separately from the failed combined
assessment. Future starters require explicit successful OS reviews as well as a
successful functional driver.

The engine's implicit Gen2 window pass bypassed classic `draw` decorators and
their pre-composition world override. Commit `974cc115` retains those classic
owners at the native UI-canvas boundary while preserving explicit native window
owners. The actual Game/Renderer regression failed 23 assertions on the prior
source; the fixed source passed 5,325 assertions across seven relevant suites,
including native Gen2 windows/scenes, input, and Gen3 UI ordering.

Combined source `de883771ffc44550b3ebbdb0d6c0c9ef8e3cc710`, including current main
`3b9a842c`, then displayed actual staged terrain, figures and upright native
"Wild PIDGEY appeared!" text in two OS captures. The world image remained
vertically inverted. That run is still failed; its manual window acknowledgement
also arrived after the 180-second review deadline. No completed-battle claim is
made for this combined-source run.

The follow-up orientation contract admits a direct override only when its exact
current canvas belongs to a ready, surface-owning battle on the native stack,
the loader/dataset/registered producer still match, and the published staging,
projection and orientation helpers match their SHA256 digests. Explicit native
and portable conventions retain priority. This additional correction still
requires current-head CI and an actual upright battle/window retest.

## Combined-main and storage follow-up

Source `a2fe4cbc0610c63ebe0c40f0cd93c1b2163309cb` incorporates main
`381e113d080745f08e2c990f13300d97af320cec`, including the native evolution and
key-item contracts. Seven focused ROM-free suites passed 884 assertions on this
exact committed source: world-canvas admission (28), direct staged canvases (45),
classic draw ownership (111), screen-space UI (35), native Gen2 battle windows
(432), evolution presentation compatibility (23), and native UI passes (210).
Hosted world-canvas/shader contracts also passed 201 assertions on `7991eaa2`
in run 40909846053. These results do not replace full CI on the combined source.

The subsequent isolated Crystal run installed the same 601 published mod files
byte-identically and reached a natural Route29 battle. Its saved OS capture now
shows upright terrain, trainer, wild Pidgey and native dialogue together. The
actual direct canvas resolved to the verified legacy orientation policy. Only
one OS capture was recorded before the manual review deadline expired; the
driver exited with a review-timeout error and the combined receipt remains
failed. Command HUD, move selection, battle completion and return are therefore
not established by this run. The saved image is scoped visual evidence, not a
successful complete battle test. ROM, original ZIPs and checkpoint were unchanged.

Following the explicit request to reclaim space, the installed storage helper
preserved and reclaimed idle managed QA copies. This maintenance freed about
2.8 GiB of actual storage, raising available space from approximately 19.8 to
22.6 GiB. The mandatory 20-GiB test reserve remains enforced. Original sources,
models, ROMs and saves were retained; no system swap files were removed. Native
children terminated and managed host cleanup completed before hardware was
returned to the other test owner.

## Staged HUD colour and extended journey findings

The official full CI for `2a4e571d6c7b8151f1aa0b0811c3e2e02cc7d9e9`
passed 990/990 engine suites, 4/4 SDK suites and all available ROM-free tiers
in run 40913135327. The hosted checkout tree was independently matched to the
committed tree. Later HUD changes below need their own current-head full CI.

Two further isolated Crystal journeys used the same byte-identical published
mods. Advancing OS captures verified an upright First Person route and battle
dialogue. Actual FIGHT input reached the public GSC `moves` state and displayed
TACKLE/LEER, NORMAL and 35/35 PP. The first driver's `moveSelect`-only assertion
was wrong; its failure was corrected in the private driver, not in the engine.
The later run completed a normal native victory and returned to the route.
The original ROM, ZIPs and earned lab checkpoint remained unchanged.

These journeys are **not visual passes**. HP bars appeared white despite full
native 48-pixel HP, correct ROM palettes and a direct published HUD texture
containing green. A naturally reached Rattata encounter also placed figures
behind raised terrain. The normal SAVE dialogue was readable but exposed an
underlying START-menu CACHE row between its panels. The private driver then
waited without pressing A at the overwrite dialogue's scrolling third line;
its assertion ended that run before saving/restart. The driver now advances
that native page using normal A input. No save/restart pass is claimed.

The focused engine correction keeps staged GSC panels and their HP/EXP tiles
on the direct colour path, avoiding the additional grayscale zone composition.
Ordinary Gen2 panels retain their zone pass, Gen1 keeps its existing protocol,
and a provider that unloads or declines surface ownership cannot select this
path. Source `10cb5a9d` passed 106 assertions through real native panel/HUD
methods. Its unchanged engine implementation on `af83c205` also passed native
scene (60), classic draw-owner (111), Gen2 window (432), and native UI (210)
regressions. The initial new test fixture had replaced the species palette
dictionary and failed during construction; preserving that dictionary fixed
the fixture without changing the engine implementation.

The staged-colour correction still requires a real window retest. Terrain
occlusion, SAVE modal stacking, completed save/restart and the remaining Yellow
and standalone mod combinations remain required. A negative-source comparison
was deferred because another owner acquired the hardware lock; no parallel
test was started.
