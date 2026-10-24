# RFC 0005 — Automatic import of audited Gen3 terrain palette programs

Status: implemented on the native foundation branch. Origami port paused;
actual-ROM import/CPU pixel acceptance is recorded separately from fixtures;
full-game/GPU acceptance remains open.

## Motivation and decision extended

RFC 0004 implements a native palette-cycle mechanism, but stock imports did
not supply declarations. Extends that RFC and D14's parity rule in plan
`21-testing-and-ci`, as preserved in `tests/engine/gate_meta_coverage.lua` and
`CONTRIBUTING-mods.md`. The numbered plan is absent from this checkout.

## Exact delta

No new public API, registry, event, hook, mod permission, mod manifest field,
save field or generated registry schema. The normal Gen3 data-stage list adds
`extractTilesetPalettePrograms` after `extractTilesetAnimations`. It hashes
the actual input ROM, analyzes tileset initializers read-only, and imports
audited runtime programs from a manifest `terrainPalettePrograms` profile.

`map_tilesets` records gain `paletteCycles` (complete array or absent) and
`paletteProgram = {version=1, status, id?, romSha1?, reason?}`. The existing
`_romInfo` gains a summary. Program offsets/classifications, source commit and
exact hash live in the two retail manifests and the regeneration catalog.
Unknown hashes or instructions, ambiguous callback assignments, unrecognized
runtime programs and malformed source data remain explicitly unavailable.

The initial profiles cover Emerald BPEE rev 0 and FireRed BPRE rev 0. Emerald
Battle Dome unfaded palette frames are imported (four frames, 16 colours at
absolute BG colour 128, cadence 4). The audited tile-only/null programs get
empty declarations. FireRed gets no invented palette cycle. Runtime clock
reset phase, fades and battle-transition task state remain outside the current
colour contract. See `docs/gen3-palette-program-import.md` for complete bounds,
source evidence, stage ordering, diagnostics and compatibility.

## Migration and parity

Existing mods do nothing; API 1/2 and base/animated reads retain their shape.
Existing caches require re-import before the colour-source read can become
complete. Unknown legacy/malformed programs retain the native base fallback;
a repeated import removes stale successful declarations first. Valid audited
palette programs intentionally become visible after re-import. No player save
or installed runtime is modified by the new data stage.

API-1 content register/override/get, events:on, hooks:wrap, mod.log, mod:read,
manifest fields and pokemon.before_give remain unchanged. The guide's absent
example_mew_starter is not claimed tested; existing supported SDK fixtures run.

## Validation

Three original ROM-free Lua suites exercise all source-pinned classifications,
actual synthetic headers including FireRed's swapped callback field, automatic
stage/hash/cache serialization, identity and malformed-source refusal, stale
metadata removal, and public-only API-1/2 consumers for both games with complete
RGBA comparisons. Six Python tests pin catalog/manifest regeneration,
exact-hash refusal and read-only checker transport. Fixtures inject hashing
explicitly; no retail-ROM acceptance follows from those fixtures. Separately,
both supported real dumps pass full callback coverage and 42,496 CPU RGBA
comparisons through APIs 1/2, including visible Emerald palette changes;
`docs/gen3-palette-program-import.md` records the evidence and limits.
No GPU performance or full-game claim follows. Existing native and
SDK regression suites remain required, with no disabled tests or golden changes.
