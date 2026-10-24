# RFC 0003 — Public animated terrain source observations

Status: implemented on `codex/native-origami-foundation`; not native Origami
acceptance. The Origami-specific port remains paused.

## Motivation

The base graphics contract offers only shipped tile bytes. A native renderer
consuming it cannot display the currently selected water/flower/fountain
picture or determine whether its cached source palette changed. Re-deriving
an animation clock in the consumer drifts when a display mode is toggled.

## Decision and plan extended

Extends D14's parity gate per extension point in plan `21-testing-and-ci`, as
preserved by `tests/engine/gate_meta_coverage.lua` and `CONTRIBUTING-mods.md`.
The numbered plan itself is absent from this checkout. Extends RFC 0002 and
`docs/gen3-render-data-v1.md` with a separately negotiated read; it does not
change the original base schema or require API 3.

## Exact API delta

Add `mod.renderData:supportsAnimation(version)` and
`mod.renderData:animatedTileset(version, expectedActiveMapId, targetMapId?)`.
Version 1 is Gen3-only. The complete bank/layout result is extended with
`graphicsState = "animated-source"`, native `animation` clock/frame metadata,
materialized selected tile bytes, packed bank `paletteRGB8`, and an exact
`contentKey` independent of clock ticks. See
`docs/gen3-animated-terrain-v1.md` for schema, errors and bounds.

Implementation reuses native `Gen3Tiles` rules on a fresh decoder and reads
only an already loaded native clock. It preserves the current native shared
cadence and 16-picture cap, with explicit imported animation completeness.
Source palette changes are observed; weather grading and palette-cycling
callbacks are outside this source contract. No registry, event, hook,
manifest, permission or save schema changes.

## Migration and compatibility

Existing mods do nothing. Base `tileset()` remains base; new methods are
opt-in. API-1 register/override/get, events:on, hooks:wrap, mod.log, mod:read,
manifest fields and pokemon.before_give remain untouched. Current public
consumer tests load API 1 and API 2. `mods/example_mew_starter` is named by
the contributing guide but absent from this fork; no run of it is claimed.

No-mod rendering/clock behavior is unchanged: no engine call site invokes
the new observer automatically. It changes no source data, loaded decoder,
sheet cache, RNG or GPU state, and cannot create a Game or renderer. Existing
no-mod gates and the new observational-purity cases remain required checks.

## Tests

The public-only consumer is loaded through the actual mod loader for both
Emerald and FireRed and both manifest APIs. The driver exercises the real
native clock and compares complete decoded pixel layers with native
compositing, plus mid-frame/cycle content equality, palette edits, bounds,
short banks, overlap precedence and source/cache isolation. Missing clocks
and unsupported generations fail explicitly. CI runs both new suites and the
existing engine gates. No gameplay or GPU performance claim is derived from
these headless tests.
