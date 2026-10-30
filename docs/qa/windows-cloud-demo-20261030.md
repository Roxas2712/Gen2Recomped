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
- Packaging guards: **3 tests passed**, unsafe paths, PE architecture and
  private-data rejection. These do not execute a Windows binary.
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
  --out /path/to/new-output-folder
```

The builder rejects an existing output folder and preserves old packages.
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

Native Windows qualification and final package execution are pending at this
report revision. Record their run URLs, results and final archive digest here
after completion. A clean Windows CI host still does not reproduce the
reported existing player's “paused” case; confirm with the updated build on
that PC and inspect logs if it persists. Real two-device account restoration,
native gameplay and exact modded-battle continuation are separate checks.

Optional native 3DS/Pinball libraries in the previous Mac demo are not silently
represented as available Windows components. Existing imported files remain
preserved; supported Windows native components are required to run those games.
No server migration or production deployment is required for this client port.
