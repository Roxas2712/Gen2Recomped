# Gen3 palette cycles and weather colour observations, version 1

The engine implements independent palette animation and exposes its colour
sources through the existing public `mod.renderData` handle. This is native
engine groundwork; the Origami-specific port remains paused.

```lua
local r = mod.renderData
if r and r.supportsColor and r:supportsColor(1) then
  local graphics, graphicsError = r:colorTileset(1, expectedActiveMapId, residentTargetMapId)
  local weather, weatherError = r:weatherColor(1, expectedActiveMapId)
  -- Both reads may decline independently; retain native rendering on failure.
end
```

Version 1 supports Gen3 with either manifest API 1 or API 2. Negotiation is
host support, not a promise that a cache has complete palette metadata.
No new permission, registry, event, hook, save field or manifest API is added.
Base `tileset()` and `animatedTileset()` retain their original palette semantics.

## Colour graphics

`colorTileset()` accepts the same mandatory expected **active** map ID and
optional resident target map ID as `animatedTileset()`. It has that contract's
complete banks/layout and selected tile picture, plus:

| Field | Meaning |
| --- | --- |
| `graphicsState` | `"color-source"` |
| `primary.palettes`, `secondary.palettes` | detached current palettes after each bank's declared cycles |
| `primary.paletteRGB8`, `secondary.paletteRGB8` | each bank's 768 packed RGB bytes matching those tables |
| `paletteAnimation.ticks` | same native clock sample as `animation.ticks` |
| `paletteAnimation.complete` | true: both banks explicitly declare their cycles |
| `paletteAnimation.primaryFrames`, `secondaryFrames` | zero-based selected picture/rotation for each declared run, in declaration order |
| `contentKey` | exact content token over selected tile bytes, current palettes, entries, layers, layout and pair identity |

Palette runs keep independent cadences, phases and lengths. They do not use
the tile animator's shortest shared cadence or 16-picture cap, and do not
multiply the number of baked tile pictures. Reducing ticks modulo a cycle
before adding its phase preserves precision up to 2^53−1. A tick without a
pixel change keeps the content key; returning to identical content reuses it.
Retain only the current key, as with the animated-source contract.

Weather is **not baked into these palettes**. It is a screen composite applied
after the world, so terrain, actors and other world objects receive the same
tint while UI remains separate. Applying a weather filter to tile palettes
alone would give different colours at character/terrain boundaries.

## Native source metadata

Each `map_tilesets` bank may declare a plain dense `paletteCycles` array.
An explicit empty array means known static. A missing array means unknown
legacy source and makes the public colour-graphics read decline; the native
renderer retains its original base palettes. No runtime attempts to execute
cartridge callbacks or infer an animation from similar colours.

Two run shapes are supported:

```lua
{ kind = "rotate", first = 17, count = 4, step = 3, phase = 0, direction = 1 }
{ kind = "frames", first = 129, count = 2, step = 5, phase = 1,
  frames = { "<six RGB bytes>", "<six RGB bytes>" } }
```

`first` is a zero-based **absolute BG colour index** (`paletteSlot * 16 +
colourIndex`), including in the secondary bank. `count` is a colour count.
Every destination must belong to its declaring bank according to
`palettesInPrimary`. Runs can cross palette slots within their own bank.
Index zero of each slot retains the decoder's existing transparency rule;
changing its RGB does not make transparent terrain pixels opaque.

`step` is an integer 1–65535 in native terrain ticks; optional `phase` is an
integer 0–65535 added to that run's clock. `rotate` requires at least two
colours and direction +1 or −1. Positive rotation shifts a source colour
toward larger destination indices, wrapping within the run. Rotation always
reads the original source palette, so repeated observations do not accumulate
drift. `frames` has 2–256 complete RGB8 strings of exactly `count * 3` bytes.
At most 32 runs total and 256 KiB of declared RGB frame data per pair are
accepted. Sparse arrays, metatables (including protected ones), invalid
numbers and incomplete frames decline. Last declared overlapping run wins.

Native `Gen3Tiles:setPaletteTicks()` uses the same pure sampler. The native
flat renderer updates both existing layer textures and all their tile-frame
variants when selected palette content changes. Reflection covers and each
renderer’s border fill are refreshed too. Texture, cover-quad, batch and
border-Canvas identities are retained. Multiple draws in one tick never
advance a cycle or upload it twice. Invalid/removed metadata restores base
palettes on the next tick. Re-import/source replacement still requires the
existing native sheet invalidation; structural tileset edits are not a live
GPU geometry-reload contract.

**Importer boundary:** the current stock Gen3 importer extracts tile frames,
not these palette-cycle declarations. This change does not mark its existing
records static or claim to extract the original palette programs. A cache
producer must supply verified declarations before stock palette programs can
animate through this path. Automatic extraction remains separate work. The
tests supply original synthetic declarations, not ROM-derived palettes.

The reason this boundary matters is visible in the primary sources:
[Emerald's tileset callbacks](https://github.com/pret/pokeemerald/blob/master/src/tileset_anims.c)
include palette copying/blending and transition state, while
[FireRed's terrain animator](https://github.com/pret/pokefirered/blob/master/src/tileset_anims.c)
primarily queues tile transfers. No cadence or palette destination is guessed
from a tile's VRAM destination. Full cartridge fade/task behaviour is not
implemented by the two declarative run shapes above.

## Weather filters

`weatherColor()` describes only the **active world's** screen colour filter;
it has no target-map argument. A neighbor does not get a second weather tint.

| Field | Meaning |
| --- | --- |
| `version`, `generation`, `mapId` | 1, 3 and expected active map identity |
| `weatherId`, `name`, `resolved` | saved active weather byte, imported name and resolved cycle appearance |
| `kind` | `"screen-overlays"` |
| `ticks` | overworld weather frame, independent of terrain clock |
| `cycleStage` | committed save stage; absent means native default zero |
| `veil` | detached normalized RGBA, transparent zero when absent |
| `flash` | white lightning overlay alpha, zero when absent |
| `scale`, `bias` | three-component affine composition for opaque world pixels without particles |
| `contentKey` | colour-only equality token; excludes ticks, names and particles |

Native order remains **world → veil → weather particles → white flash → UI**.
For each opaque input channel `C` without a particle at that pixel:
`Cout = C * scale + bias`, where
`scale = (1 - veil.a) * (1 - flash)` and
`bias = veil.rgb * veil.a * (1 - flash) + flash`.
This uses the renderer's numeric colour space, without promising gamma,
framebuffer quantization or cartridge palette-blend parity. Particles remain
between the two layers; the affine form alone does not describe them.

The shared native helper is `Gen3Weather.colorFilter()`. All existing veil
colours, particles, flash timing and the final draw-state reset remain
unchanged. These are the fork's reconstructed looks, as already documented
in `Gen3Weather.lua`, not newly extracted GBA weather colour tables.

The observer reads `save.gen3WeatherActive`, `save.gen3WeatherStage` and
`world.weatherFrame`. It does not invoke `gen3WeatherStage()` (which can write
the save and read wall-clock time), advance weather, change script state or
load a renderer/Game. It reports the last committed daily stage; native
calendar processing remains responsible for advancing that stage. This is
not an independent realtime calendar/weather engine or weather-audio API.

The default renderer continues to apply its native screen weather to a custom
world result. Merely observing this descriptor does not opt out of that
composite. A future consumer must avoid applying it again before the native
overlay; this change adds no weather-ownership/takeover switch.

## Failure and acceptance

Missing/invalid cycle metadata returns `nil, "palette animation data unavailable"`.
Missing/invalid terrain clock returns `nil, "terrain clock unavailable"`.
Missing save/weather names, unknown weather and invalid weather frame/stage
return `nil, "weather color unavailable"`. Other errors retain the base
contract's version, generation, active-map, residency and source validation.
No partial coloured tileset is returned on failure.

Four ROM-free suites run in default and dedicated CI:

- `gen3_color_data`: API 1/2, Emerald/FireRed, complete decoded pixels against
  independently selected expected palettes, independent clocks and content keys.
- `gen3_color_failures`: metadata, bounds, overlaps, reverse rotation, precision,
  legacy refusal, static equality and missing clocks/generations.
- `gen3_palette_renderer`: real native bake/window/border/cover paths on
  pixel-bearing texture stand-ins; tests all variants, shared-pair borders,
  retained objects, no repeated uploads and actual fallback pixels.
- `gen3_weather_color`: complete baseline draw-command parity including
  particles, both APIs/games, 18 weather names, all daily stages and lightning
  boundaries, and save/RNG/IO/GPU purity.

These establish data, CPU pixel and renderer-call correctness, not stock ROM
import completeness, actual GPU behaviour, performance, screenshot/gameplay
acceptance or First/Third Person. Palette changes currently recolour the
affected pair's complete atlas. Benchmarking/optimizing this opt-in path and
real context loss, resize and reload acceptance remain release work.
