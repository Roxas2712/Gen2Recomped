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

## Remaining engine work

| Area | Remaining acceptance/work |
| --- | --- |
| Terrain graphics over time | animated source observations and cache-change token implemented; palette-cycling callbacks, weather grading, GPU invalidation and performance acceptance remain |
| Neighbor streaming | public readiness/preparation lifecycle beyond already resident maps |
| Buildings, trees, bridges, interiors | native object/geometry metadata and lifecycle; surface codes alone do not provide meshes |
| Camera and controls | native public camera/input ownership suitable for First/Third Person |
| Weather and sky | native state, clock and audio contracts; clouds/weather renderer acceptance |
| Map battles | public battle state/action/presentation lifecycle and field transitions |
| Resource lifetime | real GPU/context loss, resize, reload, warp and memory acceptance |
| Runtime integration | a native consumer using these contracts, followed by Emerald/FireRed gameplay acceptance |
| Fork health | inherited CI failures repaired in the 2026-10-24 follow-up; keep CI and native gameplay acceptance as separate release gates |

These items are a work ledger, not an overall completion percentage. Existing
separate proposal branches may supply parts of them; they must be reviewed,
integrated and tested on the combined engine before being marked accepted.
