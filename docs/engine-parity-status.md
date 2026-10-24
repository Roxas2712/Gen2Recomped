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

| Area | Current evidence | Remaining acceptance |
| --- | --- | --- |
| Public mod APIs, hooks, input, storage, scripts, content, live maps | Portability integration `10421a5` merged; composed ROM-free engine/SDK/B30 tests pass | Audit full behavior against reference, including dynamic calls, unsupported targets and rollback; most changes already have separate upstream PRs |
| Central map-music ownership | Actual native Music contract compared across eight games, 168 checks per engine; unmodified VASC weather adapter activates in real Red | Upstream PR [#192](https://github.com/UNDERdecoded/Gen2Recomped/pull/192); broader audio/music contracts remain to audit |
| Legacy 3D image orientation on LÖVE 12 | Corrected on OpenGL and Metal; real VASC/KASC exterior and interior, First/Third Person and V switch; independent asymmetric world/UI/FX pixel oracle | Upstream PR [#193](https://github.com/UNDERdecoded/Gen2Recomped/pull/193); Windows hardware and broader producers remain unverified |
| Native Gen3 palettes and presentation | ROM palette-program importer, animated colors, GPU readback/presentation and frame-reuse work implemented in this fork | Continue real Smaragd/Feuerrot regression checks on each composed release candidate; baseline performance results do not automatically transfer to a new composition |
| Real VASC integration | Official Voxel Ascendant 3.0.65-rc.4 and Kanto Ascendant 6.7.35-rc.2 packages load unmodified on the composed 0.8.45/API-3 preview in Red | Walking, normal warps/doors, battle transitions, in-world battles, movement/collision, options, effects, lifecycle, long sessions and additional supported games are not fully accepted |
| Game scope of supplied VASC packages | Both manifests target Gen1; VASC generation dispatcher also selects Gen1 | Loading in Red does not establish Smaragd/Feuerrot mod support; do not change manifests or bypass compatibility gates |
| Content registries | Exact schemas audit: 43 fork keys versus 48 reference keys | `apricorns`, `decorations`, `landmarks`, `phone_contacts`, `radio_channels`: map actual native producers/consumers, port and test real behavior |
| Jobs, steps, networking and asset/import dependencies | Module-name inventory only; some equivalents may live under different names | Audit semantic contracts for jobs/workers/cancellation, steps, net, asset packs, required imports, dependency/game/version rules, sandbox and filesystem boundaries |
| Battle/world/data compatibility | Composed native and portable contract suites pass their covered cases | Audit remaining public unified battle/world/script/record contracts and real mod consumption; test battle-entry/exit and map lifecycle on real hardware |
| Saves and link | Fork metadata currently shell 2 / link 2 / save 4; reference shell 3 / link 3 / save 5 | Compare layouts and protocols before migrations or cross-engine compatibility claims; no version-number-only bump |
| Additional cartridges/revisions | Independent LeafGreen/Ruby/Sapphire Rev0 work already exists as upstream PRs #183/#186/#187 | Review integration and actual import layouts; later revisions must not be accepted by hash alone |
| UI, tools, audio and other native features | Source inventory available; shared filenames are not a complete behavior audit | Establish concrete feature matrix and fixtures for remaining reference capabilities |
| Distribution | Existing Windows/macOS native-preview release and isolated packaging; actual release version stamping and clean macOS archive extraction fixed | Publish tested updates in the existing release; Windows execution and complete release-level parity acceptance remain open |

Tests and acceptance are scoped evidence. A visible frame does not prove its
orientation, a loaded mod does not prove all its features, and an engine-wide
unit suite does not replace real gameplay or a Windows GPU run. The final
all-features release objective remains open until these checks are resolved.
