# RFC 0002 — Compose native Gen3 render observations and expose cell surfaces

Status: implemented on `codex/native-origami-foundation`; not a release or a
claim that Origami runs natively yet.

## Motivation

A future renderer should consume the fork's public engine contracts rather
than duplicate engine internals in an Origami-specific adapter. Five existing
branches offered terrain, portable world callbacks, actors, field effects and
surf mounts separately. They need combined-loader coverage. Their terrain
snapshot also omitted the elevation, collision and behavior codes needed to
interpret bridges and raised terrain safely.

## Decision and plan extended

Extends D14's parity gate per extension point from plan `21-testing-and-ci`,
as recorded in `tests/engine/gate_meta_coverage.lua`, and Lane B of
`CONTRIBUTING-mods.md`. The numbered plan itself is not included in this
checkout. Extends the existing render pipeline and the versioned Gen3 terrain
contract documented in `docs/portable-oasc-world-pass.md` and
`docs/gen3-render-data-v1.md`. It does not adopt the separate API-3 proposal.

## Exact API delta

Add `mod.renderData:supportsSurface(version)` and
`mod.renderData:surface(version, expectedActiveMapId, query?)`.
Version 1 is Gen3-only; the query, bounds, residency and active-map guard are
the terrain contract's. The result is a detached terrain snapshot extended
with dense `elevations` (0–15), `collisions` (0–3) and `behaviors` (0–255).
See `docs/gen3-surface-render-data-v1.md` for precise defaults and failures.
Live zero-valued patches win; behavior follows the patched metatile.
Elevation 15 is preserved as a semantic marker, never turned into a height.

The loader installs terrain, actor, field-effect and surf-mount methods on a
single handle before publishing it and executing the mod entry. Existing
feature branches are merged as ancestors so their provenance is preserved.
The surf dependency also moves Gen3 bob advancement from pose/draw to fixed
update, so observing or replacing a draw cannot drive or freeze the clock.
Legacy GB draw-owned behavior is retained; normal visual gameplay acceptance
of the Gen3 timing remains required before release.
No registry, event, hook, manifest or save schema is added by this new surface
extension. The integrated world-pass dependency adds the already documented
optional `render_pipelines.worldFormat = "renderData.v1"` field; registry docs
are regenerated from the combined catalog for validation.

## Migration and compatibility

Existing mods do nothing. All APIs are additive; the ordinary terrain snapshot
and legacy render callbacks keep their original shapes. API-1 content
register/override/get, events:on, hooks:wrap, mod.log, mod:read, manifest fields
and pokemon.before_give are retained. Existing loader/runtime/SDK regression
tests remain the compatibility checks. The contributing guide names
`mods/example_mew_starter` as a fixture, but that directory is not tracked in
this fork; it is not invented or silently counted as tested here. The new
integration consumer explicitly loads through both manifest API 1 and API 2.

No-mod boots construct no observation handles, add no pipeline or observation
content, and keep native world rendering. Readers do not bootstrap Game, load
maps, decode caches, consume RNG, draw or read files. Only explicit sheet
source requests use the existing bounded source readers.

## Validation and limits

`tests/engine/native_foundation.lua` exercises the actual public consumer in
Smaragd/FireRed-shaped resident fixtures, including a real registry-dispatched
portable world callback. `tests/engine/gen3_surface_data.lua` covers no-mod
boots, native defaults, stale/unloaded maps, bounds, malformed cell sources
and observational purity. Existing terrain, actor, effect, mount, native clock
and resource tests exercise the combined host. Dedicated CI runs these tests
without ROMs or a display.

The broad ROM-free runner is compared with an isolated export of main
`13af468b97dc37015d14ad5c71d7f067c3ee810d`. Its pre-existing failed suites stay
visible; no golden is blessed and no coverage debt is waived to hide them.
Visual gameplay, First/Third Person, full Origami rendering, native battles,
weather and streamed neighbor preparation remain separate acceptance work.
