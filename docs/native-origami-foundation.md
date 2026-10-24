# Native renderer foundation in the Gen2Recomped fork

The Origami-specific port is paused. Work here develops the public engine
contracts a future native Origami consumer can use. This branch contains no
private Origami source/assets, imported ROM/cache data or player saves.
The existing Gen1 checkout and player runtime are outside this work.

Base: `13af468b97dc37015d14ad5c71d7f067c3ee810d` (main, v0.8.45).
Development branch: `codex/native-origami-foundation`. This is not a release.

## Integrated engine contracts

| Capability | Source branch / commit | Current scope |
| --- | --- | --- |
| Terrain graphics and resident placements | `codex/gen3-render-data-contract` / `c33d4d3` | detached resident grids and base tilesets |
| Portable world callback | `codex/portable-oasc-world-pass` / `cb56e73` | detached frame, graphics fence, native fallback |
| Actors | `codex/portable-actor-render-data` / `4507c1e` | native poses and explicit source reads |
| Field effects | `codex/portable-field-effect-render-data` / `ffebd37` | grass, ripples, sparkles and their sources |
| Surf mounts | `codex/portable-surf-mount-render-data` / `90b5446` | native mount/rider observations; Gen3 update-owned bob |
| Cell surfaces | this branch / [RFC 0002](rfcs/0002-native-render-foundation.md) | live raw elevation, collision and behavior, including resident neighbor crops |
| Animated terrain sources | this branch / [RFC 0003](rfcs/0003-animated-terrain-sources.md) | selected native animation picture, fresh source palettes and exact content-change token |
| Palette cycles and weather colours | this branch / [RFC 0004](rfcs/0004-palette-cycles-weather-colors.md) | independent colour cycles, native sheet/border/cover refresh, public native veil/flash observations; [audited stock palette-program import](gen3-palette-program-import.md) |

The loader composes every family on one handle before executing a consumer.
The new surface contract preserves elevation 15's bridge semantics and reads
zero-valued script patches correctly. It does not infer 3D building geometry
from collision or height codes.

The surf dependency intentionally moves **Gen3** bob advancement from pose/draw
to fixed update. Repeated reads/draws no longer advance it; skipped draws no
longer freeze it. The fixed-update clock test covers hopping, landing, free
movement and legacy GB behavior. This needs normal gameplay acceptance before
a release; the headless tests do not establish full visual parity.

## Validation on the combined branch

2026-10-23, locally built LuaJIT 2.1, ROM-free headless fixtures:

- **13 focused suites pass, 4,848 checks.** This includes 312 surface/no-mod
  checks and 1,444 combined-loader checks across Emerald/FireRed and API 1/2.
- The combined consumer reads terrain, surfaces, actors, field effects and
  mounts inside the public pipeline boundary. It imports no private engine
  modules and deliberately declines drawing to test fallback. Explicit image
  source requests are also tested on that same public handle.
- Registry documentation generates successfully from the combined schema.
- T4 mod-SDK and Dramatic Shape B30 pass in the broad runner.
- At the original 2026-10-23 checkpoint, T1/T2 failed the **same ten suites**
  as an isolated export of unchanged main. That historical baseline is in
  [the report](qa/native-foundation/contracts.json). The 2026-10-24 follow-up
  fixes those failures; see [CI health](ci-health-repair.md) for current evidence.
- Imported-content/link and gameplay/visual tests were not run. No First/Third
  Person or full Origami acceptance is claimed. No screenshot golden changed.

`native-foundation.yml` adds dedicated CI for the combined contracts; results
above are local results, not a claim that hosted CI has completed.

The 2026-10-24 animated-source follow-up adds two public-loader suites with
3,132 checks for native pixels/clock behavior, source changes and invalid data.
The local default runner now passes 92/92 engine suites, 3/3 mod-SDK suites
and Dramatic Shape B30. Hosted validation is recorded on the PR's exact head;
this remains source/data acceptance, not full Origami or GPU gameplay acceptance.

The subsequent palette/weather-colour follow-up adds four suites with 44,284
checks. The local ROM-free runner passes 96/96 engine suites, 3/3 mod-SDK
suites and Dramatic Shape B30; Python cache-policy tests, unchanged mod lint,
Lua parsing and generated registry reference also pass. The suites exercise
the public API for both games/APIs and native texture refresh with synthetic
data and pixel-bearing graphics stand-ins. Existing stock caches still lack
palette-cycle declarations: automatic cartridge-program extraction and real
GPU/gameplay acceptance are not claimed. See the
[colour contract](gen3-color-data-v1.md) for the exact boundary.

The next follow-up adds automatic palette-program import for the exact audited
Emerald/FireRed rev-0 profiles, described in
[RFC 0005](rfcs/0005-rom-palette-program-import.md). Three new Lua suites pass
2,655 checks, including actual synthetic source headers, digest refusal,
binary cache serialization and public API-1/2 pixel tests; six Python tests
keep both manifests and regeneration catalog aligned. The local ROM-free
runner passes 99/99 engine suites, 3/3 SDK suites and B30. The earlier note
about missing automatic declarations describes the previous checkpoint;
existing installed caches still require re-import. Actual-ROM acceptance
is now recorded in the separate
[observed-digest/callback-coverage report](qa/native-foundation/palette-program-import.json):
73/73 Emerald and 63/63 FireRed source tilesets recognized, zero unknown
programs, and 42,496 successful real-source RGBA comparisons through APIs 1/2.
Both input dumps remained unchanged; no installed caches, saves or player
sessions were used. These are import/CPU pixel results, not GPU/gameplay acceptance.

The separate live-game follow-up now tests the complete fresh imports and
native flat-world renderer on Apple M3 / Metal (LÖVE 12 build `937eb3b`).
Emerald's four Battle Dome palette phases match actual GPU atlas/readback
pixels and a fixed visible floor cell; FireRed's static palettes coexist with
all 16 native tile-animation frames. Real second-map entry/return and FireRed
indoor movement are included. Independent test identities bypass legacy-save
migration before main loads; no installed player cache, save or mod is used.
See the [GPU evidence and limitations](gen3-palette-program-import.md#native-live-game-gpu-acceptance-2026-10-24)
and [metadata report](qa/native-foundation/palette-program-gpu.json).
LÖVE 11.5/OpenGL black window captures reproduced without game code, so that
backend had no window acceptance at that checkpoint. This targeted native palette test does
not accept general gameplay, performance, context loss, Battle Dome scripting
or a future Origami/First/Third Person consumer.

The [macOS window-frame follow-up](window-frame-recovery.md) now restores
visible output when OpenGL's system framebuffer is undefined and routes
Metal captures through a completed GPU target. Separate Emerald/FireRed
instances pass 3,964 continuous steady-state frame checks and 24 actual OS
window captures across LÖVE 11.5/OpenGL and LÖVE 12/Metal/OpenGL, with zero
blank/stale frames. Movement, map entry/return and window resize pass.
The independent ROM-palette GPU oracle passes all six combinations too.
The local runner passes 100/100 engine suites, 3/3 SDK suites and B30.
OpenGL recovery incurs per-frame GPU readback/image transfer; performance,
context loss and broader platform acceptance remain open. See the
[metadata report](qa/native-foundation/window-frame-recovery.json) for scope.

## Remaining engine work

| Area | Remaining acceptance/work |
| --- | --- |
| Terrain graphics over time | audited Emerald/FireRed palette import and scoped native flat-world OpenGL/Metal GPU/window tests pass; additional ROM profiles, cartridge fade/task/reset-phase semantics, general GPU invalidation and performance acceptance remain |
| Neighbor streaming | public readiness/preparation lifecycle beyond already resident maps |
| Buildings, trees, bridges, interiors | native object/geometry metadata and lifecycle; surface codes alone do not provide meshes |
| Camera and controls | native public camera/input ownership suitable for First/Third Person |
| Weather and sky | native colour-only veil/flash observations implemented; weather takeover, full state/audio contracts, cartridge colour tables and clouds/weather renderer acceptance remain |
| Map battles | public battle state/action/presentation lifecycle and field transitions |
| Resource lifetime | scoped macOS window resize and map return pass; general GPU/context loss, reload, warp, long-duration and memory acceptance remain |
| Runtime integration | a native consumer using these contracts, followed by Emerald/FireRed gameplay acceptance |
| Fork health | inherited CI failures repaired in the 2026-10-24 follow-up; keep CI and native gameplay acceptance as separate release gates |

These items are a work ledger, not an overall completion percentage. Existing
separate proposal branches may supply parts of them; they must be reviewed,
integrated and tested on the combined engine before being marked accepted.
