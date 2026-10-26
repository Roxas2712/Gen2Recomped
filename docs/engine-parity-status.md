# Engine parity work ledger

Status: **in progress; full parity is not established**. This work concerns
native engine compatibility in the Gen2 fork. The separate Origami port stays
paused. Existing Gen1 installations and player profiles are outside the test
scope and are not used or modified.

Reference: clean, read-only Gen1Recomp dev `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`;
Gen1 stable v0.3.96. Original Gen2 upstream base:
`13af468b97dc37015d14ad5c71d7f067c3ee810d` (release v0.8.45).
File-path differences are audit candidates, not missing-feature counts. No
percentage can be inferred from them or from the number of passing tests.

Current composed preview checkpoint: `4be92945c94e603f7cc582cde23d4702d9610e4a`.
Native radio records/script lifecycle and window-resolution Pokegear are merged
as PR39/45. This exact source passes418/418 engine suites, SDK3/3, all quick
tiers and four-platform runtime qualification40248573841. Fresh real-Crystal /
unchanged-Johto OpenGL and Metal runs pass46 checks each with8 independently
inspected OS windows in both selected cameras. All six existing preview
assets were refreshed and remote digests verified; the original tag is unchanged.
Metal warning overlays and full radio programs/audio remain open.

Native development main checkpoint: `f027780f78e41142ef78d80d2298398fa794df18`.
Phone PR53/54/56/57/58 and radio PR48 are merged. Its complete Git tree
`d38e3ba881b905d3735aa5acb98c4b783f0e9d0a` exactly matches frozen integration
source `46bfcce15d814ac4349b76a8a41b5370015dadff`, which passes435/435 engine
suites, SDK3/3 and every ROM-free quick tier, including current P4 main.
This is ahead of the public preview. Runtime qualification40262481115 is
pending; no new packaged or GPU acceptance is inferred. See the
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
| Content registries | Native `radio_channels` is merged and the existing preview includes PR39/45. Native `phone_contacts` now binds semantic identities to the actual numeric Pokegear/incoming/VM consumers, with strict validation, stable IDs, reserved holes, rollback and reload ownership; PR53/54 merged. Imported Crystal Buena and both call directions are restored. See [native phone content](native-gen2-phone-content.md) | `apricorns`, `decorations` and `landmarks` still need actual native producers/consumers, target isolation and rollback. Phone authored scripts/forward references and full legacy facade remain open. Registry-name counts do not measure overall parity |
| Native Gen2 radio music / Snorlax gate | PR48 merged: actual station playback, map-cue ownership and five-cell/native-song gate,167 native Music/input/VM checks across Gold/Silver/Crystal. Upstream PR275 offers the standalone implementation. Merged main is included in the435-suite integration checkpoint | Diagnostic9f, composedd1 and paced8c each have scoped OpenGL/Metal acceptance with twelve inspected OS windows, real flute Sources and non-silent PCM. Later432 has OpenGL acceptance; its last Metal OS capture was correctly rejected as stale while macOS reported a locked screen. None proves hardware acceptance for current main. Full ROM show text/timing/schedules, jingles, music-show choices and original-story acceptance remain open |
| Native Gen2 phone book and callbacks | PR53/54/56/57/58 merged. Actual native10-slot order/reservations/deletion/scrolling, semantic contacts, detached `phone.contact_list` and native caller-byte selection are implemented. Focused checks:138 import,326 content,277 book,316 hook,5204 selection. Merged main passes435/435 engine suites. Upstream PR285 includes native API1/2 equivalents: sourceb77b27bb passes69/79 versus base13af64/74 with exactly the same ten existing failed suites/assertions, SDK3/3 | Full legacy Phone facade, authored new scripts/forward references, complete special-call/rematch contracts, fresh-import phone GPU/story acceptance and long sessions remain open. Unified API2/3 checks apply to the own fork only. No full phone parity or upstream-green claim |
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
