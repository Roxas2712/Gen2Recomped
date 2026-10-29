# Engine parity work ledger

Status: **in progress; full parity is not established**. This work concerns
native engine compatibility in the Gen2 fork. The separate Origami port stays
paused. Existing Gen1 installations and player profiles are outside the test
scope and are not used or modified.

Reference: clean, read-only Gen1Recomp dev `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`;
Gen1 stable v0.3.96. Original Gen2 upstream base:
`13af468b97dc37015d14ad5c71d7f067c3ee810d` (release v0.8.45).
Main now also contains upstream's `ed5189c247ee7a2ccca666784e21fd4fba8df781`
major update through fork PR61, preserving the fork's native interfaces.
File-path differences are audit candidates, not missing-feature counts. No
percentage can be inferred from them or from the number of passing tests.

## Current checkpoint, 29 October 2026

The fetched fork main is `d822aba828156f9e2fda32aac0a667649a2c5247`,
including transport-test PR354, stat-refresh PR353, native Pokemon-field PR352, screen-position PR351, native frame-query PR350, the qualified native battle batch PR349, GBA evolution PR344 and
the earlier native RNG PR336. PR349's exact composed tree passes942/942
engine suites,4/4 SDK suites and every available official ROM-free tier;
all77 exact-head CI checks succeeded or were skipped before its strict
merge. Its earlier standalone PR341/346 reviews are closed as superseded
after verifying that adding their heads changes no byte of current main.
The preceding
RNG merge `43abf33d` has 88 successful/skipped exact-head checks and an
independently qualified identical tree: 934/934 engine suites, 4/4 SDK suites
and all available official ROM-free tiers. Current main is integrated into
the native battler development branch; the earlier receipt does not qualify
the subsequently changed combined tree.

The newest release by publication time observed through GitHub's release
API is `desktop-test-20261028.3`, RetroRecomped 0.8.57, published
28 October at 20:02:55 UTC from `90a3b093e62d85440d0a1b8288e30e0caf3cc358`.
`native-preview-20261028.2` is a separate earlier preview. Neither release
is qualified here as containing all subsequent main/development changes.
No release assets were updated during this checkpoint.

Historical friendship source `26037683` passes a complete independent run:
936/936 engine suites, 4/4 SDK suites and every available official ROM-free
tier. Its merge gate stopped when main advanced through PR344 during that
run. The subsequently qualified PR349 composition contains friendship,
the round-clock implementation and battler extraction on the newer main.
The public live clock has
400 focused checks, actual native link observations have 210 and semantic
checkpoint observations have 57. The
[battler data/presentation extraction](native-battler-construction.md),
has 691 plain-Lua checks without LÖVE, 972 checks through actual wild
constructors/switches across 18 editions, and 270 independently matched
original-versus-extracted native data/art-selector cases.
Native Game2 frame/viewport queries are merged PR350. Its initial
real Metal check identified a drawable-pixel/DPI mismatch missed by the
logical-input tests. The correction passes4454 expanded query checks plus
the existing viewport/window/chrome regressions. A fresh owned Metal run
with unchanged VASC confirms the actual drawable query agrees with native
composition, after real checkpoint CONTINUE, a connected walk and a natural
encounter. Four inspected OS images cover both selected field camera flags;
both select the same authored battle-stage view. All27336 mod files/copies,
ROM and earned source checkpoint retain their hashes. Exact head `7da7b119`
passes943/943 engine suites,4/4 SDK suites and every available official tier;
all76 exact-head CI checks succeed or are skipped. The actual main merge has
the identical qualified tree. This does not accept full visual parity:
bottom command artwork is partly clipped in both the existing Gen1 reference
and fresh fork images, whose logical hit layouts agree but DPI/lighting differ.
The corresponding coherent older-host offers
are upstream PR396 (battle foundations) and PR397 (frame queries with the
already offered viewport/chrome prerequisites). No upstream merge occurs.

[Native screen positioning](native-screen-position.md) is merged PR351: CENTER/UPPER/TOP, saved native options, safe top insets,
skin/split ownership and enough world coverage below a raised camera. The
selected actual fitting/input/save/boot/final-blit probe passes1151 checks.
Upstream PR398 independently passes1031 position,4454 frame-query and116
chrome checks through its actual older compositor and flat options menu.
Exact head `a6eb0c05` independently passes944/944 engine suites,4/4 SDK
suites and all available official ROM-free tiers. All77 latest exact-head
CI checks succeeded or were skipped, including the same-head rerun of a
failed macOS transport timeout. The strict merge tree equals the qualified
tree. Actual GPU/window and release qualification remain open.
[Live native GSC Pokemon fields](native-gen2-mon-fields.md), merged PR352,
addresses five actual missing source field reads on native Pokemon records.
Corrected source `23d4aaa5` passes184 pure-data,177 native and100 actual
world/battle checkpoint checks, plus all13 checkpoint suites that failed
in the first complete run. The corrected codecs retain strict refusal of
custom runtime state and byte-identical recapture. Earlier construction,
identity and save regressions also passed on the initial source. The preceding
engine fails all five source-field checks and the absent-helper check.
Exact source `da71c3d3` passes947/947 engine suites,4/4 SDK suites and every
available official ROM-free tier; all83 exact-head CI checks succeed or are
skipped. Strict merge `152e2372` has the identical qualified tree. A real
unchanged-VASC Crystal instance verifies party fields and the actual CENTER
option/source query. CUA reports the Mac locked; the bounded run ends with
no OS image and does not accept the remaining positions or camera/battle
phases. All original/copy mod, ROM and source checkpoint hashes match.
Actual unchanged-mod GPU/window and final release qualification remain open.
Upstream PR399 independently passes184 pure-data/170 actual older-host native
checks plus4454/116/1031 frame/chrome/position regressions.

[Native GSC stat refresh](native-gen2-stat-refresh.md) is merged PR353:
shared native/source formula, explicit source identity argument order,
actual summary recalculation and weak shared-combat-stat rebinding. Source
273692e8 passes185360 data/238 native checks and existing identity, summary,
field, battler and checkpoint regressions; predecessor main fails the exact
new source formula/signature/refresher probes. Exact PR head `aabc0ed5`
passes949/949 engine suites,4/4 SDK suites and all available official
ROM-free tiers; all74 latest CI checks pass or are skipped. Strict merge
`25c67691` has the identical qualified tree. Upstream PR400 composes actual
original main `8d5b4387` and the offered appearance, Unown, battler and field
prerequisites. Its independently corrected older-host source `26114b40`
passes all17 selected suites, including185360 formula/238 native refresh
checks; the initial composition's cross-generation binding regression was
fixed and the original negative-generation guards now pass.

[Download worker retirement](native-download-worker-retirement.md), merged
PR354, corrects a transport fixture race without changing production workers,
queue bounds or request timeouts. Its real official LOVE11.5 macOS TLS
fixture passes1512 checks and the exact final PR head `0185fb13` passes all
949/949 engine and4/4 SDK suites. All70 exact-head CI checks succeed or are
skipped, including three real platform transports and separately dispatched
native HTTP, import and package contracts. Strict merge `d822aba8` has the
identical independently qualified tree.
[Source PP operations](native-gen2-mon-pp.md), draft PR355, add the actual
native slot API and shared healing/save repair. Corrected source `43f697d8`
passes6642 new checks and six actual existing regression groups. The exact
fixture against predecessor main fails25 missing-method probes. Full composed
qualification is pending; no unchanged-mod menu interaction or release
acceptance is inferred.

Full source-model `Battle.new`, the standalone turn/event API and arbitrary
writable model fields remain open; these foundations do not close them.

Recent unchanged-VASC evidence includes a real 80,842,206-byte sprite-pack
download, native save/restart, verified mount and decoding all 120 images
in that pack. The drawn Cyndaquil follower selected the mod's bundled
flame-card runtime, so this does not prove downloaded-pack actor selection
or every package. A Metal native victory spent three PP and awarded EXP
135 to 151; a later image was already another encounter, so stable world
return still needs visible proof. The latest OpenGL attempt reached both
camera selections and battle admission but exceeded its story deadline
before an accepted attack. It is retained as a failed attempt.

Matched Gen1/fork visual and conditional menu coverage, every relevant
download path, full native source-model semantics, and exact Windows/macOS
package acceptance remain required. The ledger below retains historical
source-specific evidence; older “remaining” entries are not a fresh audit
of current main and older previews are not the current release.

Historical public preview: `ed564cb54fb42f1ea5c977ceb38fe883f3ceae07`, merged
as fork PR97 (`c79921ff`, identical tree `a7122aa5`). The existing
`native-preview-20261025.1` Windows/macOS assets were updated in place. All
six served hashes, binary manifest, release text and unchanged original tag
were verified. This source passes485/485 engine suites, SDK3/3 and all quick
tiers; exact-source runtime qualification40353017055 passes all four targets
and hosted component assembly. Native display/composition GPU probes pass253
checks on each of OpenGL and Metal.

The unmodified fused Mac package passes78 natural Crystal/unchanged full-VASC
checks per backend, including clock/Oak/name entry and the original initial
room, five display selections and First/Third Person. Twelve inspected own
OS-window phases per backend each require two increasing frame stamps. ROM,
mod, payload and runtime bytes are verified unchanged. True-colour mod art
retains its RGB contract in DMG/custom; Classic colours the completed scene.
The hosted Mac HTTP job was cancelled before acquiring a runner; the same
workflow command passes locally with the byte-verified official LOVE11.5
runtime:1935 checks plus TLS POST coverage. This is not a green-hosted-CI,
full story/save/link, physical Windows/Intel-Mac GPU or full-parity claim.

Subsequent main integration `d9865fed` (tree `d539ed67`), including the
independent friend features, passes489/489 engine suites and SDK3/3. Its
additional changes have CPU integration evidence; the published binary
remains the frozen source above. Native save-menu PR109 is a separate draft;
its earlier `10cf0b7c` checkpoint passes101 focused checks and486/486 suites.
Real save/reload and unchanged-mod GPU acceptance for that new owner remain
open. Native START now has a separate class and retains its submenu parent;
its focused input/lifecycle coverage passes67 checks. Real save presentation
was rejected after inspection; missing native PC owners still prevent the
complete resolved presentation watcher from installing. The remaining PC
menu owners, battle animation/HP seams and
natural Mom/starter/story/save/link coverage are still part of this ledger.

Historical verified public preview: `a1008ce933ab3a6784e909f52f61b0fceecc29e8`
(own PR80, merged as `e5160b54`; identical frozen engine tree). The existing
`native-preview-20261025.1` Windows/macOS assets were refreshed in place;
all six remote digests, manifest and release text were verified and the original
tag retained. This exact source passes463/463 engine suites, SDK3/3, all quick
tiers and four-platform runtime qualification40297459060 attempt2. Exact-source
OpenGL/Metal pixel probes cover indexed palette drawing and unchanged native
front/evolution consumers. The unchanged full supplied Johto package passes102
selected PC/mail/palette/RTC checks on each backend, in First/Third Person,
with eight inspected fresh OS images. Setup is staged; complete story/art,
physical Windows/Intel GPU and full mod/parity acceptance remain open. See the
[palette drawing receipt](qa/native-foundation/native-gen2-pokemon-palettes.json).

Historical native GSC Unown candidate: `9ef5109eef1cecb0e7b5a25b44e2ffb47c9bb75e`
(own PR82; upstream standalone PR307). It shares native form identity, imported
words, caught order, actual party/box/gift registration, counter/menu reads and
one completed-form event. This frozen candidate passes465/465 engine suites,
SDK3/3, every quick tier and66,288 focused checks including all65,536 DV-byte
combinations. A private read-only Crystal word-producer/reference check passes80
assertions. Later main registry-descriptor changes are being composed and
revalidated separately. At that checkpoint this Unown candidate was not in the a100 preview;
later preview sources include subsequent integration. Full reference Unown API and story/GPU acceptance remain open.
See [native Unown state](native-gen2-unown.md).

The older checkpoints below retain their own evidence and limitations. They
are historical receipts, not claims about every feature in the latest source.

Historical native recipe integration candidate: `acd8ea46ab98a1c3651cde82491b1be0175ddee3`
(PR67). Its frozen tree passes444/444 engine suites, SDK3/3 and all quick
tiers, including443 recipe/VM checks and120 native program import checks.
A read-only Crystal probe executes an added recipe through original Kurt
selection, map reentry, working/day flags, full-bag refusal and three-ball
collection with one completion event. Upstream PR295 offers native API1/2,
with exactly the same eleven existing baseline failures. At this historical checkpoint, runtime qualification
40270319573 was recorded separately; no new release/GPU/story acceptance is
inferred from that receipt. See the [native recipe receipt](qa/native-foundation/native-apricorn-content.json).

Historical composed development checkpoint:
`9abcd876b0420c25d6223d25b840b72eac0904f0`. Phone incoming-event PR60 and
native apricorn producer/selection PR63 are merged alongside native transition
PR55 and the upstream refresh. The exact complete Git tree passes439/439
engine suites, SDK3/3 and every ROM-free quick tier. Runtime40265754962 is
recorded separately for this frozen source (now completed). Earlier sourcef027 passed all four runtime
platforms and both desktop packages, but that does not qualify this new tree.
At that historical checkpoint the public preview was source4be; fresh exact-source GPU/story
acceptance is still open. See the
[apricorn/integration checkpoint](qa/native-foundation/native-apricorn-main.json).
This historical source's recipe import was correct, but its old-cache fallback
order was wrong and its old test oracle missed it. PR65, source1ff0618d,
corrects that fallback;216 checks and all seven positions of the actual
Crystal table agree. Runtime40265754962 and static desktop packaging have
since passed, but the historical9abcd source is superseded and is not a
release candidate. No fresh GPU/story acceptance follows from packaging.

Historical public preview checkpoint: `4be92945c94e603f7cc582cde23d4702d9610e4a`.
Native radio records/script lifecycle and window-resolution Pokegear are merged
as PR39/45. This exact source passes418/418 engine suites, SDK3/3, all quick
tiers and four-platform runtime qualification40248573841. Fresh real-Crystal /
unchanged-Johto OpenGL and Metal runs pass46 checks each with8 independently
inspected OS windows in both selected cameras. All six existing preview
assets were refreshed and remote digests verified; the original tag is unchanged.
Metal warning overlays and full radio programs/audio remain open.

Historical native development checkpoint: `f027780f78e41142ef78d80d2298398fa794df18`.
Phone PR53/54/56/57/58 and radio PR48 are merged. Its complete Git tree
`d38e3ba881b905d3735aa5acb98c4b783f0e9d0a` exactly matches frozen integration
source `46bfcce15d814ac4349b76a8a41b5370015dadff`, which passes435/435 engine
suites, SDK3/3 and every ROM-free quick tier, including current P4 main.
This is ahead of the public preview. Runtime qualification40262481115 and both desktop package checks have since
passed; this does not establish fresh GPU acceptance for later sources. See the
[phone/radio checkpoint](qa/native-foundation/native-phone-radio-main.json).

Earlier PC/mail checkpoint: `6004286e4659d993c0ded87a2677247a610a15b8`.
Native PC/mail and the event-data-pointer import correction are merged. The
same exact source passes engine 380/380, SDK 3/3, all ROM-free quick tiers,
and Windows/Linux/Intel-Mac/Apple-Silicon runtime qualification. With actual
Crystal and the unchanged supplied Johto package, selected PC/mail flows pass
68 checks per OpenGL/Metal backend; eight fresh OS-window images inspected.
The [PC/mail receipt](qa/native-foundation/johto-native-pc-mail.json) records
setup, rejected attempts and visible limitations. Existing `20261025.1`
Windows/macOS assets are refreshed in place and all six remote digests verified.
This checkpoint does not extend older scoped gameplay results to new behavior.

| Area | Current evidence | Remaining acceptance |
| --- | --- | --- |
| Public mod APIs, hooks, input, storage, scripts, content, live maps | Portability integration `10421a5` merged; composed ROM-free engine/SDK/B30 tests pass | Audit full behavior against reference, including dynamic calls, unsupported targets and rollback; most changes already have separate upstream PRs |
| Central map-music ownership | Actual native Music contract compared across eight games, 168 checks per engine; unmodified VASC weather adapter activates in real Red | Upstream PR [#192](https://github.com/UNDERdecoded/Gen2Recomped/pull/192); broader audio/music contracts remain to audit |
| Legacy 3D image orientation on LÖVE 12 | Corrected on OpenGL and Metal; real VASC/KASC exterior and interior, First/Third Person and V switch; independent asymmetric world/UI/FX pixel oracle | Upstream PR [#193](https://github.com/UNDERdecoded/Gen2Recomped/pull/193); Windows hardware and broader producers remain unverified |
| Native Gen3 palettes and presentation | ROM palette-program importer, animated colors, GPU readback/presentation and frame-reuse work implemented in this fork | The Gen3 port remains paused; composed ROM-free regressions continue. Previous performance/GPU results do not automatically transfer to new compositions |
| Actual supplied Johto package | Unchanged VASC `3.1.2-omega.1.8` (27,329 files), native Crystal Rev0, exact packaged `0acb23b7` engine and qualified universal runtime: OpenGL and Metal each pass 213 checks, 12 ordinary door/connection transitions, four menus and four fresh OS-window proofs in selected First/Third Person | This is scoped acceptance after explicit QA introduction/map setup. Default visible contacts, every interior/story path, long sessions and complete effect/model parity remain open |
| Native Gen2 camera and movement | Native phase ownership, collision/forced-motion handoffs, permission queries and actual-VM coordinate contracts implemented; the `0acb23b7` packaged transition runs exercise both selected camera modes and ordinary doors/map seams | Complete field-action admission/presentation, all terrain/story conditions and physical Windows/Intel GPU acceptance remain open; see [camera/movement](native-gen2-camera-movement.md) |
| Runtime compiler/host capacity | Actual pinned LÖVE 12 hosts and stock-60/experimental-120-upvalue LuaJIT closure/C API/thread/FFI qualification: Windows, Linux, Intel Mac and Apple Silicon all pass at exact `6004286e`, run40238124576. Both packaged payloads match; universal Mac strict ad-hoc signature verified. A Windows canonical-fixture CRLF checkout regression was reproduced, corrected with a targeted LF attribute and passed the real Windows qualification | Qualification is source/component-bound. Mac is not notarized; Windows/Intel hardware GPU gameplay and new engine compositions need separate acceptance |
| Native battles with unchanged Johto | The `0acb23b7` package passes 20 staged native-battle checks per OpenGL/Metal backend, both selected field cameras, colored Pokémon sprite cards in the 3D arena, real FIGHT/move input, damage and win callbacks, without battle-provider fallback | The QA party and battle are explicitly staged. Ordinary visible-contact admission, capture/party-switch/RUN, complete animation/model parity and story combat remain open |
| Native Gen2 follower interface | Native optional NPC controller now exposes `setShouldSpawn` / `current` through the legacy Gen2 name. Focused 159 checks cover actual movement, connection carry/rebase, hook precedence, generation isolation, real loader teardown and failed-entry rollback; [fork PR18](https://github.com/Roxas2712/Gen2Recomped/pull/18), [upstream PR157](https://github.com/UNDERdecoded/Gen2Recomped/pull/157) | Packaged `5aebfb4c` passes scoped unchanged-mod ownership checks on OpenGL (366) and Metal (400), each twelve transitions and four fresh window proofs. PR18 is merged. Question-mark placeholder art remains visible in some Center views; native fallback art, every mode and full story lifecycle are not accepted; see [follower contract](native-gen2-party-follower.md). The existing public preview now includes this interface through `b9aa8f2e`; its new species tests do not requalify the full earlier follower transition matrix |
| Native Gen2 field-action facade and regional map | `FieldMoves` now exposes native GSC flight destinations and visited flags to the actual picker; the retail town-map LZ decoding and Crystal Silver Cave region are corrected. Exact `8ab72ab8` package passes 84 checks per OpenGL/Metal backend: both regional images match an independent real-ROM decoder, eight fresh OS map images inspected across First/Third, two actual flights per backend at exact imported coordinates; see [flight/map receipt](qa/native-foundation/johto-native-town-map.json) | QA intro/map/party/visited/Hall-of-Fame marker are staged. Native story unlock and Hall-of-Fame flag production, badge/party admission, complete cinematic, legacy action context/result protocols, sprite helpers and terrain queries remain open. Existing Metal warning overlays still obscure the lower map edge; cursor/art/UI parity is not complete |
| Native GSC species-name lookup | Live aliases preserve native rows/IDs; real registry/loader/creation regression145 checks, CI367/367 engine+SDK3/3. Exact `b9aa8f2e` package with unchanged Johto/Crystal: OpenGL85 and Metal77 checks, both cameras outside/Center, actual ambient sprite/pose bindings and eight fresh window proofs; [scoped receipt](qa/native-foundation/johto-native-species-names.json). Fork PR27 merged; standalone upstream PR261 submitted; existing `20261025.1` assets refreshed in place from this exact source | Individual actors may be off-screen in the window proofs. Missing optional full-colour sheets, complete sprite/model/story parity, Metal warnings and Windows/Intel hardware GPU remain open |
| Native GSC PC/mail and script targets | Fork PR30/32/34/35 merged. Native party/boxes/mail, script gifts/delivery and detached callbacks; actual PC special/boot return, provider transfers and mailbox menus pass 68 checks per OpenGL/Metal backend in both selected cameras. Real Crystal import has 388 maps and 5,038 scripts, zero desyncs; upstream PR264 and PR268 ready for review | Every PC/UI mode, stationery art, SRAM mail conversion, ordinary story admission, friendly item labels and complete art remain open. Metal warnings obscure part of the second letter line; focused-window acceptance does not prove background presentation |
| Content registries | Native `radio_channels` is merged and the existing preview includes PR39/45. Native `phone_contacts` now binds semantic identities to the actual numeric Pokegear/incoming/VM consumers, with strict validation, stable IDs, reserved holes, rollback and reload ownership; PR53/54 merged. Imported Crystal Buena and both call directions are restored. See [native phone content](native-gen2-phone-content.md) | `apricorns` now binds imported Kurt programs to actual recipe selection, native event/ball delivery and completion observers, with rollback and reload isolation; see [native apricorns](native-gen2-apricorn-selection.md). The legacy Apricorns facade, full tree/day lifecycle and story/GPU acceptance remain open. Native `landmarks` now binds semantic names/coordinates to the actual numeric town-map and script consumers, with edition-specific identity counts and region boundaries; see [native landmarks](native-gen2-landmarks.md). `decorations` now has native registry/placement integration and an explicit legacy adapter; see [native decorations](native-gen2-decorations.md). Original-story/hardware breadth remains open. Phone authored scripts/forward references and full legacy facade remain open. Registry-name counts do not measure overall parity |
| Native Gen2 radio music / Snorlax gate | PR48 merged: actual station playback, map-cue ownership and five-cell/native-song gate,167 native Music/input/VM checks across Gold/Silver/Crystal. Upstream PR275 offers the standalone implementation. Merged main is included in the435-suite integration checkpoint | Diagnostic9f, composedd1 and paced8c each have scoped OpenGL/Metal acceptance with twelve inspected OS windows, real flute Sources and non-silent PCM. Later432 has OpenGL acceptance; its last Metal OS capture was correctly rejected as stale while macOS reported a locked screen. None proves hardware acceptance for current main. Full ROM show text/timing/schedules, jingles, music-show choices and original-story acceptance remain open |
| Native Gen2 phone book and callbacks | PR53/54/56/57/58 merged. Actual native10-slot order/reservations/deletion/scrolling, semantic contacts, detached `phone.contact_list` and native caller-byte selection are implemented. Focused checks:138 import,326 content,277 book,316 hook,5204 selection. Merged main passes435/435 engine suites. Upstream PR285 includes native API1/2 equivalents: sourceb77b27bb passes69/79 versus base13af64/74 with exactly the same ten existing failed suites/assertions, SDK3/3 | Full legacy Phone facade, authored new scripts/forward references, complete special-call/rematch contracts, fresh-import phone GPU/story acceptance and long sessions remain open. Unified API2/3 checks apply to the own fork only. No full phone parity or upstream-green claim |
| Native incoming phone observation | PR60 merged. Actual random/special controller queues emit `phone.call_received`; native/unified delivery, selected receive programs, completion, authored contact names with retained trainer class, mutations/false returns, outgoing/rejected calls and rollback are covered by499 checks. Sourcef775 passes436/436; upstream PR285 source0fb2ad45 includes native API1/2 equivalents (259 event checks),70/80 versus base13af64/74 with identical ten existing failed suites/assertions | Complete PhoneRing choreography, Mom shopping-call production, full legacy facade, story and hardware acceptance remain open |
| Native Kurt selection / ApricornBalls producer | PR63 merged. Actual cartridge pairs/order and bounded completeness metadata feed the real selector; Gold/Silver single-item handover, Crystal quantity confirmation/reselection/cancel, scrolling and atomic bag revalidation are covered by198 checks. Actual native collection preserves an event on refusal and clears it only after the confirmed quantity lands. Source610f passes438/438; latest composition9abcd passes439/439. Read-only Crystal probe finds7 complete rows with independent decoder agreement, original ROM unchanged. Upstream PR295 source0594 is based on currented518:64/75 versus63/74 with identical eleven existing failed suites/assertions; SDK3/3 | Complete apricorn registry/legacy facade, authored event/ball-output binding, native daily/tree lifecycle and original-story/GPU acceptance remain open. ROM scripts retain ball choice/flags; no alternative job model or guessed script remap is introduced |
| Jobs, steps, networking and asset/import dependencies | Shared datetime/native power services and independent native-step delivery interfaces merged as fork PR31/PR33 and retained in `6004286e`. Scoped mod-worker changes are included | Complete the reference semantic audit for workers/cancellation, steps, networking, asset packs, imports/dependencies, target/version rules and sandbox boundaries. Desktop runtime tests do not establish mobile sensor hardware acceptance |
| Battle/world/data compatibility | Composed native and portable contract suites pass their covered cases | Audit remaining public unified battle/world/script/record contracts and real mod consumption; test battle-entry/exit and map lifecycle on real hardware |
| Saves and link | Fork metadata currently shell 2 / link 2 / save 4; reference shell 3 / link 3 / save 5 | Compare layouts and protocols before migrations or cross-engine compatibility claims; no version-number-only bump |
| Additional cartridges/revisions | Independent LeafGreen/Ruby/Sapphire Rev0 work already exists as upstream PRs #183/#186/#187 | Review integration and actual import layouts; later revisions must not be accepted by hash alone |
| UI, tools, audio and other native features | Source inventory available; shared filenames are not a complete behavior audit | Establish concrete feature matrix and fixtures for remaining reference capabilities |
| Distribution | Existing `native-preview-20261025.1` Windows/macOS assets refreshed in place from qualified `4be92945`, including native wall-radio and sharp Pokegear presentation plus including earlier flight/map/species changes plus PC/mail and the event-target import fix. All six remote asset digests, notes and manifest verified; original tag/source archives retained. The fixed release profile was never launched for QA | Latest scoped PC/mail tests cover selected scenes after explicit QA setup. Earlier battle/door/map/follower receipts retain their original source. Full native parity and complete hardware/gameplay acceptance remain open |

Tests and acceptance are scoped evidence. A visible frame does not prove its
orientation, a loaded mod does not prove all its features, and an engine-wide
unit suite does not replace real gameplay or a Windows GPU run. The final
all-features release objective remains open until these checks are resolved.
