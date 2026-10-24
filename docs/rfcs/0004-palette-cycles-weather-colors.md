# RFC 0004 — Native palette cycles and public weather colours

Status: implemented on the native foundation branch. Stock palette-program
extraction and GPU/gameplay acceptance remain open; Origami port paused.

## Motivation and decision extended

RFC 0003 observes animated tile bytes but only base palettes. A future native
consumer cannot reconstruct independent colour timing or observe the same
weather tint as the native screen compositor. Extends D14's extension-point
parity rule in plan `21-testing-and-ci`, as preserved by
`tests/engine/gate_meta_coverage.lua` and `CONTRIBUTING-mods.md`; the numbered
plan itself is absent here. Extends RFCs 0002/0003 with opt-in colour reads.

## Exact API and runtime delta

The existing public handle adds `supportsColor(1)`,
`colorTileset(1, expectedActiveMapId, residentTargetMapId?)` and
`weatherColor(1, expectedActiveMapId)`. Schema, exact bounds, failure values,
native metadata and rendering order are specified in
`docs/gen3-color-data-v1.md`. Negotiation is Gen3-only and works with manifest
APIs 1/2. No API 3, new registry/event/hook/permission, manifest field, save
schema or cartridge files are introduced; no generated registry schema changes.

Native source records can carry bounded declarative `paletteCycles`; a pure
sampler selects RGB frames/rotations using each run's own cadence and phase.
The native terrain decoder can sample these cycles. The flat renderer updates
existing layer images, animated variants, reflection covers and border fills
on colour changes. Palette timing never changes tile picture timing or atlas
size. Existing stock caches have no declarations and retain base behaviour.
The stock importer does not yet produce declarations; this RFC does not claim
automatic extraction or full cartridge callback/fade/transition semantics.

`Gen3Weather.colorFilter()` factors out the existing veil/flash composition.
The native draw path consumes that helper without changing its visual
parameters, particle placement/order or UI separation. The public observer
reads the committed save stage and weather clock without mutating either.
It does not transfer ownership of the default weather overlay to a mod.

## Compatibility and migration

Existing mods do nothing. `tileset()` remains base, `animatedTileset()` retains
its original palette values/content token format, and legacy native sources
remain unchanged. Missing cycle metadata declines the new colour read rather
than inventing completeness. API-1 register/override/get, events:on,
hooks:wrap, mod.log, mod:read, manifest fields and pokemon.before_give are
untouched. Existing SDK, no-mod and combined-loader gates remain required.

The contributing guide's `mods/example_mew_starter` is absent from this fork;
no run of that unavailable example is claimed. The unchanged installed SDK
fixtures exercise supported API-1 compatibility.

## Validation

Public-only test mod loaded through the real loader for Emerald/FireRed and
API 1/2. Expected palette selection is calculated independently and complete
RGBA layers compared against native compositing. Native bake/window/border/
reflection paths execute with pixel-bearing graphics stand-ins. Tests cover
timing, invalidation, phase precision, overlap, retained texture/batch objects,
shared-pair border revisions, malformed metadata and fallback. Weather tests
compare all draw commands with the pre-extension path, plus explicit colour
values, affine overlay results, daily routes and lightning boundaries. Reads
are save/clock/RNG/IO/GPU-pure. No screenshot golden is changed. Real GPU,
performance, ROM-import and gameplay acceptance remain separate gates.
