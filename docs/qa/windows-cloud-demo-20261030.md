# Windows cloud demo — 30 October 2026

Integration: Roxas2712. Existing authors' rights remain unchanged.

## Source and scope

Build from the public `Roxas2712/Gen2Recomped` branch
`codex/windows-cloud-demo`, based on `7d89f8142f48e1bc543e850bcabe1285a2d756c2`.
Private RetroRecompedRS Actions remain disabled. No private game payload,
credential, ROM, imported cartridge cache or real player save is packaged.

The public port adds recommended ModCompass account sync, durable account-owned
normal-save upload work, explicit local-progress ownership selection, restore
before automatic game start, actionable status and re-import confirmation.
It retains advanced cloud providers behind Advanced. Exact runtime snapshots
and private game-import uploads remain separate opt-ins.

The Windows bootstrap discovers existing AppData profiles read-only, including
older `LOVE/` profiles and dated previews. A single existing profile is reused;
multiple profiles require selection. The selection is stored separately in
`RetroRecomped-Windows-Demo/windows-demo-profile.json`. It never migrates,
merges or deletes existing profile contents. `Profil-Auswahl.cmd` opens the
picker again. Existing portable installations keep their existing marker/data.
The bootstrap hands control to the engine's original frame loop exactly once.

## Local evidence

- Public launcher contract: **91 suites, 102 syntax checks passed**.
- German audit: **1,081 strings in 27 views, none missing**.
- Profile regression: **16 checks passed**, filesystem fixtures only.
- Updated bootstrap regression: **22 checks passed**, event-loop fixtures only.
- Packaging guards: **4 tests passed**, unsafe paths, PE architecture, private-data
  rejection and a valid synthetic diagnostic payload. These do not execute
  a Windows binary.
- **9 real local HTTPS scenarios passed** against the existing Laravel server
  with isolated accounts, SQLite storage and separate device profiles. HTTP,
  TLS, authentication and persistence are real; the headless queue scheduler
  is a fixture. No production player data was uploaded or modified.

The hardened Lua batch runner prevents an individual test's `os.exit(0)` from
silently skipping remaining suites. Portability fixes from the public desktop
qualification branch cover Windows separators and isolated relay test setup.

## Windows build gates

The pinned official Windows LÖVE 12 host is artifact `12514271124`, SHA-256
`1f4c6997bd93502f986f5187d877da84247617eede89d8140bcbf570bd07ea22`.
The replacement LuaJIT library must pass the existing stock/extended closure,
C API and complete engine checks, then the actual Windows LÖVE host, thread
and FFI checks. The component verifier binds the reports to the exact engine
Git trees; an unrelated passing runtime artifact is insufficient.

Workflow `runtime-upvalues.yml`, input `windows_only=true`, creates the
`windows-cloud-runtime` dependency. Workflow `windows-cloud-demo.yml` takes
that successful run ID, builds on Ubuntu through the normal audited packer,
then executes the **final fused EXE on Windows** with an isolated QA profile.
The latter verifies native Unicode profile discovery, preserved synthetic
bytes, bundled native HTTPS, a real anonymous HTTPS policy request and four
save/profile regression suites. Its nine checks do not upload a player's save
or play a cartridge.

Build locally after downloading the qualified component:

```sh
python3 tools/build_windows_cloud_demo.py \
  --runtime /path/to/official-love12-win64.zip \
  --component /path/to/windows-cloud-runtime/component.json \
  --native-sdk /path/to/windows-native-games/windows-native-runtime.zip \
  --native-report /path/to/windows-native-games/report.json \
  --out .local/qa/windows-cloud-demo-build/candidate
```

The builder rejects an existing output folder and preserves old packages.
Use a fresh known QA copy layout under `.local/qa/<run>/candidate`; arbitrary
temporary folders are intentionally rejected by the storage manager.
It always creates a fresh payload from the committed, clean engine inputs;
external pre-packed payloads cannot bypass the source qualification binding.
`verification.json` records source revision, runtime/component hashes, archive
and fused EXE hashes. `windowsDemoExecuted` is false at build time; the separate
native test report supplies execution evidence if that test passes.

## Remaining qualification

First Windows run `41102081370` stopped with 1,019/1,020 standalone engine
suites passing: the real-HTTPS integration client was incorrectly stored in
the auto-discovered standalone engine suite folder. It requires the local
Laravel server/configuration created by its dedicated starter. The client is
now under `tests/drivers/cloud_save_http.lua`; the dedicated HTTPS starter
still runs every one of its nine real server scenarios. The full standalone
Windows qualification must pass again; no failing check was marked successful.

Native Windows qualification [run 41105676336](https://github.com/Roxas2712/Gen2Recomped/actions/runs/41105676336)
passed on Windows AMD64: **1,019 engine suites for each of stock/extended**, both
closure/C API variants, and the actual LÖVE host/thread/FFI checks. Source
`b63cb28e98fad618b34ba9be84739cb6b0e30152` stayed unchanged during the run.
The component verifier checks its exact engine trees against the later package
source; later packaging-only commits do not silently qualify different engine
code. The relocated real HTTPS integration starter also passed all nine cases
again.

First package run `41110385151` stopped before writing a payload because its
generic runner-temporary output was not a known managed QA copy layout. The
workflow now uses `.local/qa/windows-cloud-demo-build/candidate`; reserve and
source gates remain enabled.

Final package [run 41111422478, attempt 2](https://github.com/Roxas2712/Gen2Recomped/actions/runs/41111422478)
passed packaging and **nine native diagnostic checks in the final fused EXE on
Windows Server 2025**. Attempt 1 hit a temporary official-host download HTTP
503; its unchanged retry passed. The diagnostics confirm bundled HTTPS,
account-transport availability, real Unicode profile discovery with unchanged
synthetic bytes, a real background public-policy HTTPS request and four
save/profile fixture suites. The archive was downloaded and its digest and
native EXE/source receipts were checked against each other.

| Artifact | Value |
| --- | --- |
| Windows x64 demo | `RetroRecomped-Windows-Demo-20261030.3-win64.zip` |
| Size | 64,792,239 bytes |
| Package source | `33f60d20e418cd23589b368599ba22f6b5d68641` |
| Archive SHA-256 | `869510db13b288d4ee02a5c2347dc4dee3885cb502111b8e759ae79f109b51f5` |
| Executed fused EXE SHA-256 | `2500416e52e48ac566b2aa3646a478266591b9d1f452afd8d783955ba3a03353` |

The native report is `native-test/native-package-test.json` alongside the
downloaded artifact. It explicitly records `playerCloudUploadTested=false`
and `nativeCartridgeGameplayTested=false`. A clean Windows CI host still does
not reproduce the
reported existing player's “paused” case; confirm with the updated build on
that PC and inspect logs if it persists. Real two-device account restoration,
native gameplay and exact modded-battle continuation are separate checks.

No server migration or production deployment is required for this client port.

## Native Windows game extension (20261030.4 candidate)

The candidate now builds native x64 Windows 3DS/Pinball components in the public
fork. It stages a ROM-free SDK next to the EXE, with a bundled Python/C/C++ import
toolchain, generic GBA libraries and the free replacement BIOS. Existing ROMs,
imports and player folders are not migrated or deleted. Source trees and each
SDK byte are bound to the native report before packaging.

Local extension regressions: 46 X/Y Python tests, 3 Windows metadata/cache tests,
7 packaging guards,
67 Lua native export signature checks and 23 file-error/cleanup checks passed.
Nine existing X/Y, Pinball and friend/CloudNet suites passed (532 checks).
These are headless contracts, not native Windows gameplay.

Native SDK run `41123957894` passed 56 recompiler unit tests and 10 bridge tests,
then built the generic GBA components. It stopped at a Vulkan-Headers tag-versus-
SHA comparison before final SDK qualification. Headers are now pinned to the full
commit `9fbc2a782ee3f8a4db64e7d991e23da75e893f44`; the new run must pass before
release. Native qualification additionally exercises self-authored ARM11/ARM
programs, Vulkan device creation, exact snapshot restore and SRAM replacement.
Those checks never imply a played Pokémon session or a player cloud upload.

The updated Windows engine qualification
[41124257857](https://github.com/Roxas2712/Gen2Recomped/actions/runs/41124257857)
passed on source `7e03e6bde59ca3f3974be76ca1621ee96fb9b7ba`:
**1,020 standalone engine suites per stock/extended runtime**, closure and C API
checks, followed by the actual LÖVE host/thread/FFI checks. The qualified extended
library SHA-256 is
`a85544b2f7e877b4b0795ac69d4523aad43e657186a4aaa06c531c5c3974ae6f`.
The Windows component artifact is `13010804640`; source-tree equality remains
mandatory for the final package.

SDK run `41125854544` built Vulkan but stopped copying its `LICENSES` directory;
notice directories are now retained recursively. Run `41127460663` correctly
stopped at the 4-GiB workspace budget while fetching unused PowerVR examples.
The builder now excludes test/example/debug submodules and avoids a duplicate
compiler extraction. It keeps the 4-GiB limit and 20-GiB reserve. These failures
are build evidence, not passing SDK qualification. The final report must also
pass native execution/snapshot/SRAM/PCM checks and the actual launcher backend
import/compile/prepare CLI using self-authored fixtures.

Subsequent native Windows tests identified and corrected three platform issues:
the 3DS session lease needs read access for `LockFileEx`, the Vulkan ICD needs
Windows relative-path syntax, and the software driver must support the
renderer's push descriptors. SwiftShader was rejected by the actual renderer;
the candidate uses the byte-pinned Mesa/Lavapipe 26.2.5 x64 driver instead.
Mesa's corresponding source archive and Mesa/LLVM/distributor licence notices
are included. The normal hardware driver remains preferred. No driver is
installed or registered by the application. Only the elevated disposable CI
fixture temporarily registers its own ICD value and restores that value when
finished, since the official loader ignores environment overrides when elevated.

The Windows SDK build also runs a positive/exclusive/released session-lock
regression. The launcher EXE reserves at least 16 MiB of stack, as requested by
the upstream GBA runtime; setting a DLL stack reserve cannot configure its host.
The seven packaging tests include preservation of larger existing host reserves
and rejection of truncated PE headers. Local Windows metadata (3 tests), safe
compiled-intermediate retirement (2 tests), and package checks (7 tests) passed
again after these changes. Final native execution and EXE reports remain the
release gate, not these portable tests.
