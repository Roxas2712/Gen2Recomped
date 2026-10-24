# Animated Gen3 terrain sources, version 1

The public `mod.renderData` handle adds two optional methods:

```lua
local r = mod.renderData
if r and r.supportsAnimation and r:supportsAnimation(1) then
  local graphics, reason = r:animatedTileset(1, expectedActiveMapId, residentTargetMapId)
  if graphics then
    if graphics.contentKey ~= lastContentKey then
      -- Rebuild/update owned textures from these source bytes and palettes.
      -- Keep only the current key and release retired owned GPU resources.
      lastContentKey = graphics.contentKey
    end
  end
end
```

`residentTargetMapId` is optional and defaults to the active map. The expected
**active** map ID remains mandatory even for a resident neighbor. Version and
generation negotiation is independent of the mod manifest API: both API 1
and API 2 can use version 1 on Gen3. A supporting host may still decline a
particular read because a world, source metadata or animation clock is absent.

## Data

The result has the complete bank/layout shape of
[`tileset(1, ...)`](gen3-render-data-v1.md), with these differences/additions:

| Field | Meaning |
| --- | --- |
| `graphicsState` | `"animated-source"` |
| `animation.ticks` | observed native terrain clock; integral, nonnegative |
| `animation.frame` | selected pair picture, zero-based |
| `animation.frames` | pair cycle length, 1–16 |
| `animation.step` | native cadence in terrain ticks |
| `primary.tiles4bpp`, `secondary.tiles4bpp` | complete detached source banks with the selected animation picture applied |
| `primary.paletteRGB8`, `secondary.paletteRGB8` | each bank's current 16×16 RGB palette, 768 immutable bytes, slot/color/channel order |
| `contentKey` | bounded, exact content token suitable for equality comparisons |

Original nested `palettes` RGB tables remain available and are detached. Source
metadata such as file paths, imported animation source labels, native decoders
and GPU objects are not returned. Base `tileset()` and terrain/surface reads
retain their existing output and behavior.

These are **source graphics**, not readback of the native GPU atlas. Current
palette tables are observed afresh, so source palette edits/reload changes
appear on the next read. This does not add palette-cycling callbacks, weather
color grading, darkness, full-screen fades, or their audio/state contracts.
A cached native GPU atlas can require its own existing invalidation after a
source edit; this observer does not rebuild it.

The separately negotiated [colour contract](gen3-color-data-v1.md) adds
declared palette cycles and native weather-colour observations. It does not
change this method's original palette semantics or content-token format.

## Native timing and bank semantics

The host already advances `TileRenderer`'s shared terrain clock before world
pipeline dispatch, including when a pipeline replaces the native world draw.
This observer reads that already loaded clock; it never starts, resets or
advances it. It also never loads a renderer or bootstraps Game to find one.

A new private decoder applies the existing `Gen3Tiles` rules. In particular:

- Primary destinations use primary-local tile IDs; secondary destinations
  are shifted by `tilesInPrimary`.
- The current native renderer uses the shortest declared cadence for the
  whole pair and caps the combined cycle at 16. This contract preserves that
  policy; it does not claim independent cartridge callback cadences.
- The cycle is 1 if no source metatile uses an animated tile. Frame zero is
  still applied to declared destinations, as during native sheet baking.
- Source frame zero can differ from the shipped static bytes. It is applied
  even at the start of the cycle.
- Missing `step` uses the native default 16. Overlapping runs use native
  last-run-wins order. Imported records normally have no overlaps.
- Valid animation destinations can extend beyond a compressed base bank;
  undefined intervening tiles are zero-filled, matching native transparent
  pixels. An override never crosses into the other bank.

`contentKey` is an exact length-prefixed token over the pair identity, layout,
materialized tile bytes, metatile entries, layer bytes and packed palettes.
It is not a cryptographic hash, host revision counter, globally stable asset
ID or file path. Compare it for equality and retain only the current key.
It excludes clock values: a tick without a picture change does not invalidate
content, and a cycle returning to identical content reuses the same token.
It also detects source edits under unchanged tileset addresses. Spatial map
placements and actor/FX state are separate contracts.

## Bounds and failure

Both banks need explicit `animations` arrays (empty means static) and correct
`metatileCount`. A cache predating animation extraction declines rather than
pretending all terrain is static. Requirements beyond the base bank contract:

- At most 64 runs total, plain dense arrays, 2–256 complete frames per run.
- Integral local destinations/counts wholly inside their primary or secondary
  tile bank; each frame has exactly `count * 32` bytes.
- At most 2 MiB of declared animation frame bytes per pair.
- Cadence, when supplied, is integral 1–65535.
- The observed tick is integral 0–2^53−1.

Reads retain all base residency, geometry, layout and source validation.
Missing/malformed animation metadata returns `nil, "terrain animation data
unavailable"`; a missing/invalid clock returns `nil, "terrain clock unavailable"`.
Stale maps, absent worlds, unsupported versions/generations and invalid targets
retain the base contract's errors. No partial graphics is returned on failure.

The observer retains no caches, invokes no file/graphics/RNG calls, and mutates
no native decoder or imported source tables. Work and output are bounded by
the source-bank and animation limits. Real-time performance and GPU/context
loss acceptance remain separate work.

## Validation

`tests/engine/gen3_animated_terrain.lua` loads the same public-only consumer for
Emerald/FireRed and API 1/2. It compares complete RGBA layers to native
`Gen3Tiles` compositing over clock transitions, palette edits, bank boundaries
and flips, and checks source isolation/content invalidation.
`tests/engine/gen3_animated_terrain_failures.lua` covers bounds, malformed data,
native cadence/cycle behavior, missing clocks, static fallback data, extension
of short banks, overlaps and unsupported generations. These are ROM-free
pixel/data tests, not native gameplay, screenshot or First/Third Person tests.
