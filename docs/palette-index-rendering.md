# Gen 1/2 palette-index rendering

## Inventur (T0)

Baseline: fork `main` at `e5687c08`, 26 October 2026, after the performance
series and native Gen 2 integration. T0 adds diagnostics only. No renderer
switch is enabled, no PNG/registry/hook changes, and no Gen 3/4/5 bake is
replaced. The following parts require separate PRs and qualification.

### Mod-facing image consumers (X4, before changing textures)

| Consumer | Images / pixels read | Contract to preserve |
| --- | --- | --- |
| `mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua` `staticAtlas` | `map.renderer.image`, `renderer.gen2Ctx`, `renderer.gbcCtx`; raw `Assets.imageData(tileset.image)` and PolishedAtlas | RGBA sampler, source dimensions, same per-map roof/borrowed-tile/palette colors |
| `TerrainAtlas.lua` `sourcePixels`, `gen2Pixels`, `gbcPixels`, `readback` | optional `TileRenderer.atlasImageData(renderer)`, otherwise redraws `renderer.image` into a Canvas and reads it; reimplements Gen 2/RED++ bakes when unavailable | RGBA bytes, alpha and color thresholds; optional accessor is currently absent |
| `TerrainAtlas.lua` animation, `forMap`, `forSprite` | RGBA base/animation images and source PNG pixels; CPU recolors through `TileRenderer.recolorSample` | Color and alpha during all animation frames; a bridge must cover the mod's own derived sheets too |
| `mods/DRAMATIC_SHAPE/lib/VoxelScene.lua` | `sprite:resolveImage()` for ordinary/motion/field/big-doll billboards, silhouettes and shadow passes; `TerrainAtlas.forMap/forSprite` | RGBA images for every resolver caller, including shadows; OBJ shade zero stays transparent |
| `mods/DRAMATIC_SHAPE/lib/SpriteBillboards.lua` | native `core.game3.sprite.get(...).image`, or `Assets.image(def.image)` fallback; `SpriteRenderer` frame dimensions | RGBA art and existing UV/frame geometry |
| `mods/DRAMATIC_SHAPE/lib/EngineSheets.lua` | `TileRenderer.gen3SheetsFor` and `Assets.image` prefetch | Gen 3 path excluded by X5; keep callable |
| `src/mods/ActorRenderData.lua` | `SpriteRenderer.poseFrame`, frames and true-color sheet record | Public copied asset paths/geometry, not a private index texture |
| `src/mods/RenderData.lua` | loaded TileRenderer animation clock; public copied terrain/animation/palette data | Gen 3 public render-data records; excluded by X5 |
| `src/mods/AssetTransform.lua`, `Schemas.lua`, `Loader.lua` | PNG ImageData transform context; sprite front/back paths; source override/derived search order; invalidation | Authored PNGs and paths stay authoritative; `assets.transformed` still fires |
| `src/mods/ManagerState.lua`, Loader palette-context binding | PaletteFX zones and live Gen 2 context | Existing palette/zone functions and lifecycle stay callable |

`TerrainAtlas.forMap` is not the only bridge seam. Changing `self.image` or
`resolveImage()` to RG8 would feed index bytes into the mod's RGBA shaders and
its CPU readback fallback. Preserve these RGBA views until all their consumers
have equivalent cached views. `render.compose` context, `Pipelines.present`,
`render_pipelines`, ShaderPresets, GBCFX and GbcColorCorrection are unchanged.

### Engine, UI and battle consumers

* `SpriteRenderer.new`, `resolveImage`, drawing/reflections/poses and
  `obpImage` share PNG-backed images and OBP variants. Player, NPC, remote
  players, NamingScreen, PartyMenu, UnownWall and PrismCustomization use these
  methods/frames. The compose/voxel pipeline can retain images independently.
* `TileRenderer.new`, window batches, animated tiles, border fills, grass
  feet/keyed redraw and map-only draws hold image references. `MapLoader`,
  `Map`, `OverworldController`, Tilt and editor callers request these. Static
  batches and existing renderer instances retain their own texture until a
  rebuild; clearing a module cache alone does not update them.
* `BattleState.getImage` CPU-bakes species palettes and optional cropped
  Crystal animation pictures. `AnimPlayer`, `Gen2AnimPlayer` and UI users
  consume the battle images/zones. `PartyMenu` has independent Gen 2 species
  and DMG OBP icon bakes; `PicBox` and `UnownPuzzle` bake species/art palettes.
* PaletteFX returns colors, named palettes, zones, effective/remapped ramps,
  per-map Gen 2/RED++ tile rows and OBJ rows. `Renderer:endFrame` applies zones
  to already composited grayscale, preserves true-color regions, then replays
  sprites/grass. Replay is an ordering contract. Other UI/battle consumers
  have their own zone lists, not one globally uniform palette.
* `src/render/Gen2PaletteDraw.lua` is an additional native shader facade
  (normal/keyed/remap) and protects foreign/nested uniform writes. Its shade
  quantization rounds `(1-r)*3`, whereas PaletteFX uses strict thresholds.
  They agree on canonical DMG PNG shades; arbitrary authored colors need a
  path-specific fallback. It must not be silently replaced by one quantizer.
* The native GBA compatibility facade (`src/compat/gen1/AtlasRuntime.lua`,
  `AtlasUpload.lua`, `AtlasPixels.lua`, `SpriteRuntime.lua` and
  `core.game3.field_view/sprite`) owns additional RGBA texture/buffer leases.
  Explicit mod RGB palette substitution in SpriteRuntime matches colors
  approximately and accepts true-color art; it is not a four-shade DMG bake.
  These Gen 3 records/operations are excluded by X5, despite the `gen1`
  directory name. Do not count them as Gen 1/2 four-shade bakes.

The generated reference table below includes every direct module consumer,
including Gen 3/4/5 consumers that must retain the old behavior. The X4 table
also covers indirect image/property reads that a require-only search misses.

### Bake and cache inventory

| Function / owner | Work on cache miss | Cache / invalidation | T0 counter |
| --- | --- | --- | --- |
| SpriteRenderer `getObpImage` | `mapPixel`, key color 0, palette RGB, `newImage` | `obpCache`, path/group/display/dark key; Assets invalidation | `sprites.obp` |
| TileRenderer `getShiftVariants` | Eight 8x8 shifted/recolored images via getPixel/setPixel | `shiftVariants`, path/tile/palette | `tiles.shift` per output (8 per miss) |
| `getFrameImages` | Flower/spinner strip recolor | `frameImages`, paths/palette | `tiles.frame` per recolored output |
| `getToggleImage` | Clone atlas and paste spinner/toggle strip | `toggleImages` | `tiles.toggle` |
| `getAtlasFrames` | Full atlas copies with frame slots patched/recolored | `atlasFrames` | `tiles.atlas-frame` |
| `getGen2Atlas` | Per-tile palette bake, roof overlay and mirrored variants | `gen2AtlasCache`, image/roof/special/display/daytime key | `tiles.gen2` |
| `getGbcAtlas` | RED++ group palette bake and tile aliases | `gbcAtlasCache`, per-map/display/dark key | `tiles.gbc` |
| `getKeyedTile` | 8x8 recolor with source shade-zero alpha | instance `gbcKeyed` | `tiles.keyed` |
| `bakeBorderFill` | GPU draw then Canvas readback/newImage | instance `borderFill`; still a bake, not mapPixel | `tiles.border` |
| `Assets.image/loadImage/blank` | PNG decode/upload and missing-image fallback | central and two renderer `imageCache`s | Not a palette bake |
| BattleState `getImage` | Species palette mapPixel, picture crop/alpha bounds | local `imageCache`, palette/display/crop key | Listed, not instrumented in T0 |
| PartyMenu `gen2IconImage`, `obpIcon` | Species/shiny palette, mipmaps or OBP shade lift | `iconImages`/path palette key | Listed, not instrumented in T0 |
| PicBox / UnownPuzzle | Species or puzzle palette mapPixel | screen-local caches | Listed, not instrumented in T0 |
| Credits / Gen2Intro | White-to-alpha or color-zero matte | scene caches | Alpha operation; not a palette bake |
| DRAMATIC_SHAPE TerrainAtlas | Own static/sprite/per-frame terrain CPU recolors and RGBA uploads | mod-owned cache/cacheData/animation entries | Not counted by engine bake counters |
| Native compatibility atlas/sprites | Composite source/animation RGBA, alternate upload buffers, explicit RGB mod recolor | owned jobs/leases/pools, source epoch/context | Separate native path; not a DMG cache counted here |
| Gen3PaletteFrameCache / Gen 3 recolour, borders, covers | Independent G5 FFI/index and animation work | Gen 3 palette/frame caches | Excluded by X5 |

Counting `mapPixel` alone misses every TileRenderer palette loop. T0 counts
successful **derived images**, once after upload, at the nine instrumented
Gen 1/2 world sites. It does not globally patch LÖVE or inspect every pixel.
Failed uploads, cached hits, plain PNG loads and Gen 3 work do not increment
these counters. A zero engine-world count is not proof of zero UI/mod/native
bakes: use the explicit scope above when comparing map-load measurements.

### FrameProfile measurement

F11 enables FrameProfile. Each normal 120-frame report now adds lines like
`bake tiles.shift total=8 peak=8/frame mean=0.067/frame`. Exact totals preserve
rare map-load hitches that the existing rounded calls/frame column hides.
`peak` counts the largest burst between rendered-frame boundaries, including
update/load work before draw. `FrameProfile.bakeCounts()` returns an owned
snapshot of total/current-frame/peak counts for QA. Reset, enable, disable and
report rollover discard the previous window; disabled calls allocate nothing.

CPU/GPU timings still use the existing `renderer: zones`, world/sprite and
whole-frame sections. These are CPU wall time to queue work, not GPU time.
T0 makes no performance-improvement claim. Record cold map loads separately
from warm cache frames and retain exact source/backend/profile fingerprints.

### Qualification and next parts

No index image is used in T0, so scene rendering remains on the baseline
path. Run the existing gallery, API-3, external fixtures, G5 and native GPU
checks plus the new profiling check before publishing. Results and explicit
environment limits are recorded below after the run.

T1 uses **RG8**, as authorized: R stores index 0..3 and G stores source alpha.
R8 cannot hold the requested G channel. Preserve partial alpha as well as
zero alpha. No generated asset file/path changes are permitted. Do not turn
the switch on by default before all ten required real scenes, gallery images
and voxel readbacks pass byte-exact comparisons. G5/Gen 4 GPU probes are
regressions, not evidence for these new Gen 1/2 scene comparisons.

#### T0 results, 26 October 2026

Local arm64 qualification, LuaJIT 2.1, LÖVE 11.5 OpenGL and LÖVE 12 Metal:

| Check | Result |
| --- | --- |
| Bake-window reset/disable/owned snapshots/exact hitch reporting | 15 checks passed |
| Native Gen 2 display modes, OBJ/atlas/roof/animation/battle colors | 540 checks passed |
| Gen 2 map palette context | 348 checks passed |
| Existing palette upload/zone tests | 491 checks passed |
| Example gallery | 253 checks passed; real transformed PNGs not exercised without ROM import |
| Existing G5 palette index tool | 44 checks passed |
| API-3 against pinned Gen1Recomp `535a5ec` | 200 comparisons / 400 isolated loader runs passed |
| Existing performance-rendering host, Metal | 77 checks, 12 comparisons, max byte delta 0 |
| T0 GPU host, OpenGL | 11 checks, populated profiler-off/on readbacks byte-identical |
| Authenticated external fixtures, all 17 workers run | 16 passed; FireRed `mystery_dungeon_follower` failed |

The failing fixture is reproducible on clean, unchanged fork `e5687c08`:
`src/compat/game3/Follower.lua:8` dereferences missing `npc.def`, followed by
`tests/fixtures/upstream_mods/worker.lua:115` rejecting the missing published
pack renderer. Neither file differs from the baseline. The stock fixture
runner stops there; a separate diagnostic executed every remaining worker
against the authenticated fixture bytes so later failures were not hidden.

This was the original T0 blocker. Separate PR #127 corrects native follower
ownership and fixture admission; all 17 authenticated fixture runs now pass.
The palette stages depend on that correction rather than changing Gen 3
inside the palette migration. The original T0 report preserves its measured
baseline and failure without rewriting the historical evidence.
No real-scene or voxel screenshot acceptance, map-transition timing improvement,
or zero-bake migration result is claimed.

The GPU probe counted one cold atlas and one cold OBJ image, zero additional
warm-cache bakes, then one rebuild each after invalidation (window totals 2/2).
The source fingerprints, backend details and baseline failure are retained in
[`qa/palette-index-t0.json`](qa/palette-index-t0.json).

Reproduce with explicit local runtime/reference paths:

```sh
python3 tools/palette-index-render/inventory.py --check
python3 tools/palette-index-render/check.py --lua /path/to/luajit \
  --love /path/to/love-11.5 --reference /clean/gen1-535a5ec \
  --out .local/qa/palette-index-t0
```

The runner intentionally exits nonzero for the baseline fixture failure; it
does not waive or relabel a failed check. The existing native GPU host needs
LÖVE 12 and its usual guarded `BATTLE_SOURCE_ENGINE`, `BATTLE_SOURCE_REPORT`,
`POKEPORT_IDENTITY` and backend environment.

## T1: load-time index derivation

`PaletteIndex.fromImageData(source)` derives a private RG8 ImageData and caches
it weakly by decoded source identity. R stores shade index 0..3 divided by 255;
G preserves the original 8-bit alpha. Alpha zero canonicalizes the index to 0.
This uses the existing shader's strict red-channel cutoffs .83/.5/.17, not RGB
distance or rounding to the nearest shade. The authored source is untouched.
Nothing in the engine uses the result yet; no texture/default/hook change.

RGBA8 sources use a LuaJIT FFI byte loop. Other formats/runtimes use getPixel
and setPixel. Call `invalidate(source)` after mutating source pixels, or
`invalidate()` at an asset-generation boundary. Invalidating does not release
ImageData already returned to another caller. The cache does not retain the
source image through its derived value.

`tools/palette-index-render/derive-check.lua` exhausts all 256 red byte values
and all 256 alpha byte values, compares FFI and portable results byte-for-byte,
tests strict floating boundaries, source immutability, identity reuse,
invalidation and weak ownership. These are derivation checks; real scene
rendering remains unchanged until subsequent stages.

## T2: palette LUT and opt-in shader

`PaletteIndex.lut(colors)` accepts one ramp or up to sixteen four-color ramps.
It owns one 64x1 RGBA8 nearest/linear texture (256 bytes). `update(colors)`
validates the entire input, compares copied byte values, and calls
`replacePixels` only on a change. It notices in-place mod edits, clears retired
slots on shrink and retains the same GPU image. Invalid input cannot partially
change the LUT. Call `release()` when its owner retires.

`PaletteFX.indexShader()` selects the new RG8 source/LUT fragment shader only
when `Performance.paletteIndexRendering` is true and the game is Gen 1/2.
The switch defaults to false. `PaletteFX.shader/keyedShader/sendColors` and
their existing uniforms remain unchanged. `PaletteIndex.bind` explicitly
resynchronizes sampler/slot/key uniforms after possible foreign writes.

The GPU host compares index sampling with actual CPU-baked RGBA images for
all 256 red values and 256 alpha values, three palette slots and both normal
and color-zero-keyed draws. It also checks all LUT entries, mutation/upload
deduplication, invalid input, retired slots and foreign uniform writes. No
production draw uses the new shader in T2; real-scene migration acceptance
remains pending the drawing stages.

<!-- palette-inventory:start -->
### Reproducible source references

Generated with `python3 tools/palette-index-render/inventory.py`. This lists lexical references (including re-exports), not an inferred dynamic call graph. Indirect image consumers are described explicitly above. Generation-specific files remain listed to make the X5 exclusions reviewable.

| Consumer / definition | Surface | Lines |
| --- | --- | --- |
| `src/battle/AnimPlayer.lua` | PaletteFX | [709](../src/battle/AnimPlayer.lua#L709) |
| `src/battle/BattleState.lua` | PaletteFX | [655](../src/battle/BattleState.lua#L655), [771](../src/battle/BattleState.lua#L771), [772](../src/battle/BattleState.lua#L772), [774](../src/battle/BattleState.lua#L774), [776](../src/battle/BattleState.lua#L776), [782](../src/battle/BattleState.lua#L782), [783](../src/battle/BattleState.lua#L783), [786](../src/battle/BattleState.lua#L786), [804](../src/battle/BattleState.lua#L804), [805](../src/battle/BattleState.lua#L805), [838](../src/battle/BattleState.lua#L838), [839](../src/battle/BattleState.lua#L839), [843](../src/battle/BattleState.lua#L843), [867](../src/battle/BattleState.lua#L867), [868](../src/battle/BattleState.lua#L868), [872](../src/battle/BattleState.lua#L872), [875](../src/battle/BattleState.lua#L875), [890](../src/battle/BattleState.lua#L890), [896](../src/battle/BattleState.lua#L896), [912](../src/battle/BattleState.lua#L912), [913](../src/battle/BattleState.lua#L913), [1107](../src/battle/BattleState.lua#L1107), [1108](../src/battle/BattleState.lua#L1108), [1110](../src/battle/BattleState.lua#L1110), [3777](../src/battle/BattleState.lua#L3777), [11309](../src/battle/BattleState.lua#L11309), [11310](../src/battle/BattleState.lua#L11310), [11313](../src/battle/BattleState.lua#L11313), [11400](../src/battle/BattleState.lua#L11400), [11401](../src/battle/BattleState.lua#L11401), [11407](../src/battle/BattleState.lua#L11407), [11408](../src/battle/BattleState.lua#L11408), [12222](../src/battle/BattleState.lua#L12222), [12224](../src/battle/BattleState.lua#L12224), [12225](../src/battle/BattleState.lua#L12225), [12247](../src/battle/BattleState.lua#L12247), [12248](../src/battle/BattleState.lua#L12248), [12264](../src/battle/BattleState.lua#L12264), [12268](../src/battle/BattleState.lua#L12268), [12283](../src/battle/BattleState.lua#L12283), [12286](../src/battle/BattleState.lua#L12286), [12299](../src/battle/BattleState.lua#L12299), [12300](../src/battle/BattleState.lua#L12300), [12357](../src/battle/BattleState.lua#L12357), [12358](../src/battle/BattleState.lua#L12358), [12382](../src/battle/BattleState.lua#L12382), [12383](../src/battle/BattleState.lua#L12383) |
| `src/battle/Gen2AnimPlayer.lua` | PaletteFX | [932](../src/battle/Gen2AnimPlayer.lua#L932) |
| `src/battle/Gen3Battle.lua` | PaletteFX | [44](../src/battle/Gen3Battle.lua#L44), [644](../src/battle/Gen3Battle.lua#L644), [2593](../src/battle/Gen3Battle.lua#L2593), [3272](../src/battle/Gen3Battle.lua#L3272) |
| `src/battle/WideBattle.lua` | PaletteFX | [17](../src/battle/WideBattle.lua#L17), [38](../src/battle/WideBattle.lua#L38), [476](../src/battle/WideBattle.lua#L476), [546](../src/battle/WideBattle.lua#L546) |
| `src/compat/gen1/AtlasRuntime.lua` | TileRenderer | [178](../src/compat/gen1/AtlasRuntime.lua#L178) |
| `src/core/CheckpointWorld.lua` | PaletteFX | [4](../src/core/CheckpointWorld.lua#L4) |
| `src/core/Game.lua` | TileRenderer | [2153](../src/core/Game.lua#L2153) |
| `src/core/Game.lua` | PaletteFX | [1577](../src/core/Game.lua#L1577), [1578](../src/core/Game.lua#L1578), [2145](../src/core/Game.lua#L2145) |
| `src/core/GameVersion.lua` | PaletteFX | [1116](../src/core/GameVersion.lua#L1116) |
| `src/core/ModCompat.lua` | PaletteFX | [65](../src/core/ModCompat.lua#L65) |
| `src/core/game3/field_view.lua` | TileRenderer | [190](../src/core/game3/field_view.lua#L190) |
| `src/import/BorrowedTiles.lua` | TileRenderer | [356](../src/import/BorrowedTiles.lua#L356) |
| `src/import/pmd/Sprite.lua` | SpriteRenderer | [43](../src/import/pmd/Sprite.lua#L43), [65](../src/import/pmd/Sprite.lua#L65) |
| `src/mods/ActorRenderData.lua` | SpriteRenderer | [88](../src/mods/ActorRenderData.lua#L88) |
| `src/mods/Loader.lua` | PaletteFX | [1610](../src/mods/Loader.lua#L1610), [2033](../src/mods/Loader.lua#L2033) |
| `src/mods/ManagerState.lua` | PaletteFX | [31](../src/mods/ManagerState.lua#L31) |
| `src/mods/RenderData.lua` | TileRenderer | [500](../src/mods/RenderData.lua#L500), [516](../src/mods/RenderData.lua#L516) |
| `src/render/GbcColorCorrection.lua` | PaletteFX | [6](../src/render/GbcColorCorrection.lua#L6), [118](../src/render/GbcColorCorrection.lua#L118) |
| `src/render/Gen2PaletteDraw.lua` | PaletteFX | [4](../src/render/Gen2PaletteDraw.lua#L4) |
| `src/render/Gen2Presentation.lua` | PaletteFX | [5](../src/render/Gen2Presentation.lua#L5) |
| `src/render/HudTiles.lua` | PaletteFX | [285](../src/render/HudTiles.lua#L285), [293](../src/render/HudTiles.lua#L293), [342](../src/render/HudTiles.lua#L342), [343](../src/render/HudTiles.lua#L343) |
| `src/render/PaletteFX.lua` | SpriteRenderer | [1194](../src/render/PaletteFX.lua#L1194) |
| `src/render/PaletteFX.lua` | TileRenderer | [1195](../src/render/PaletteFX.lua#L1195) |
| `src/render/PaletteFX.lua` | PaletteFX | [28](../src/render/PaletteFX.lua#L28), [37](../src/render/PaletteFX.lua#L37), [45](../src/render/PaletteFX.lua#L45), [49](../src/render/PaletteFX.lua#L49), [51](../src/render/PaletteFX.lua#L51), [53](../src/render/PaletteFX.lua#L53), [54](../src/render/PaletteFX.lua#L54), [55](../src/render/PaletteFX.lua#L55), [56](../src/render/PaletteFX.lua#L56), [84](../src/render/PaletteFX.lua#L84), [91](../src/render/PaletteFX.lua#L91), [94](../src/render/PaletteFX.lua#L94), [101](../src/render/PaletteFX.lua#L101), [103](../src/render/PaletteFX.lua#L103), [111](../src/render/PaletteFX.lua#L111), [117](../src/render/PaletteFX.lua#L117), [128](../src/render/PaletteFX.lua#L128), [131](../src/render/PaletteFX.lua#L131), [146](../src/render/PaletteFX.lua#L146), [151](../src/render/PaletteFX.lua#L151), [162](../src/render/PaletteFX.lua#L162), [163](../src/render/PaletteFX.lua#L163), [165](../src/render/PaletteFX.lua#L165), [169](../src/render/PaletteFX.lua#L169), [179](../src/render/PaletteFX.lua#L179), [181](../src/render/PaletteFX.lua#L181), [183](../src/render/PaletteFX.lua#L183), [197](../src/render/PaletteFX.lua#L197), [201](../src/render/PaletteFX.lua#L201), [202](../src/render/PaletteFX.lua#L202), [207](../src/render/PaletteFX.lua#L207), [224](../src/render/PaletteFX.lua#L224), [240](../src/render/PaletteFX.lua#L240), [259](../src/render/PaletteFX.lua#L259), [266](../src/render/PaletteFX.lua#L266), [267](../src/render/PaletteFX.lua#L267), [288](../src/render/PaletteFX.lua#L288), [300](../src/render/PaletteFX.lua#L300), [304](../src/render/PaletteFX.lua#L304), [317](../src/render/PaletteFX.lua#L317), [345](../src/render/PaletteFX.lua#L345), [352](../src/render/PaletteFX.lua#L352), [357](../src/render/PaletteFX.lua#L357), [367](../src/render/PaletteFX.lua#L367), [375](../src/render/PaletteFX.lua#L375), [376](../src/render/PaletteFX.lua#L376), [393](../src/render/PaletteFX.lua#L393), [394](../src/render/PaletteFX.lua#L394), [400](../src/render/PaletteFX.lua#L400), [401](../src/render/PaletteFX.lua#L401), [445](../src/render/PaletteFX.lua#L445), [449](../src/render/PaletteFX.lua#L449), [458](../src/render/PaletteFX.lua#L458), [459](../src/render/PaletteFX.lua#L459), [478](../src/render/PaletteFX.lua#L478), [479](../src/render/PaletteFX.lua#L479), [480](../src/render/PaletteFX.lua#L480), [495](../src/render/PaletteFX.lua#L495), [496](../src/render/PaletteFX.lua#L496), [518](../src/render/PaletteFX.lua#L518), [519](../src/render/PaletteFX.lua#L519), [522](../src/render/PaletteFX.lua#L522), [523](../src/render/PaletteFX.lua#L523), [529](../src/render/PaletteFX.lua#L529), [532](../src/render/PaletteFX.lua#L532), [533](../src/render/PaletteFX.lua#L533), [535](../src/render/PaletteFX.lua#L535), [549](../src/render/PaletteFX.lua#L549), [556](../src/render/PaletteFX.lua#L556), [568](../src/render/PaletteFX.lua#L568), [570](../src/render/PaletteFX.lua#L570), [592](../src/render/PaletteFX.lua#L592), [616](../src/render/PaletteFX.lua#L616), [620](../src/render/PaletteFX.lua#L620), [635](../src/render/PaletteFX.lua#L635), [653](../src/render/PaletteFX.lua#L653), [655](../src/render/PaletteFX.lua#L655), [666](../src/render/PaletteFX.lua#L666), [681](../src/render/PaletteFX.lua#L681), [682](../src/render/PaletteFX.lua#L682), [701](../src/render/PaletteFX.lua#L701), [705](../src/render/PaletteFX.lua#L705), [716](../src/render/PaletteFX.lua#L716), [720](../src/render/PaletteFX.lua#L720), [753](../src/render/PaletteFX.lua#L753), [754](../src/render/PaletteFX.lua#L754), [755](../src/render/PaletteFX.lua#L755), [782](../src/render/PaletteFX.lua#L782), [807](../src/render/PaletteFX.lua#L807), [808](../src/render/PaletteFX.lua#L808), [810](../src/render/PaletteFX.lua#L810), [818](../src/render/PaletteFX.lua#L818), [822](../src/render/PaletteFX.lua#L822), [826](../src/render/PaletteFX.lua#L826), [830](../src/render/PaletteFX.lua#L830), [847](../src/render/PaletteFX.lua#L847), [853](../src/render/PaletteFX.lua#L853), [855](../src/render/PaletteFX.lua#L855), [857](../src/render/PaletteFX.lua#L857), [860](../src/render/PaletteFX.lua#L860), [861](../src/render/PaletteFX.lua#L861), [882](../src/render/PaletteFX.lua#L882), [883](../src/render/PaletteFX.lua#L883), [891](../src/render/PaletteFX.lua#L891), [892](../src/render/PaletteFX.lua#L892), [897](../src/render/PaletteFX.lua#L897), [902](../src/render/PaletteFX.lua#L902), [913](../src/render/PaletteFX.lua#L913), [918](../src/render/PaletteFX.lua#L918), [922](../src/render/PaletteFX.lua#L922), [989](../src/render/PaletteFX.lua#L989), [999](../src/render/PaletteFX.lua#L999), [1000](../src/render/PaletteFX.lua#L1000), [1007](../src/render/PaletteFX.lua#L1007), [1008](../src/render/PaletteFX.lua#L1008), [1023](../src/render/PaletteFX.lua#L1023), [1024](../src/render/PaletteFX.lua#L1024), [1059](../src/render/PaletteFX.lua#L1059), [1060](../src/render/PaletteFX.lua#L1060), [1080](../src/render/PaletteFX.lua#L1080), [1087](../src/render/PaletteFX.lua#L1087), [1096](../src/render/PaletteFX.lua#L1096), [1097](../src/render/PaletteFX.lua#L1097), [1098](../src/render/PaletteFX.lua#L1098), [1104](../src/render/PaletteFX.lua#L1104), [1121](../src/render/PaletteFX.lua#L1121), [1144](../src/render/PaletteFX.lua#L1144), [1148](../src/render/PaletteFX.lua#L1148), [1152](../src/render/PaletteFX.lua#L1152), [1160](../src/render/PaletteFX.lua#L1160), [1161](../src/render/PaletteFX.lua#L1161), [1162](../src/render/PaletteFX.lua#L1162), [1167](../src/render/PaletteFX.lua#L1167), [1171](../src/render/PaletteFX.lua#L1171), [1173](../src/render/PaletteFX.lua#L1173), [1174](../src/render/PaletteFX.lua#L1174), [1175](../src/render/PaletteFX.lua#L1175), [1176](../src/render/PaletteFX.lua#L1176), [1178](../src/render/PaletteFX.lua#L1178), [1179](../src/render/PaletteFX.lua#L1179), [1183](../src/render/PaletteFX.lua#L1183), [1184](../src/render/PaletteFX.lua#L1184), [1185](../src/render/PaletteFX.lua#L1185), [1211](../src/render/PaletteFX.lua#L1211), [1218](../src/render/PaletteFX.lua#L1218), [1222](../src/render/PaletteFX.lua#L1222), [1223](../src/render/PaletteFX.lua#L1223), [1227](../src/render/PaletteFX.lua#L1227), [1228](../src/render/PaletteFX.lua#L1228), [1230](../src/render/PaletteFX.lua#L1230), [1231](../src/render/PaletteFX.lua#L1231), [1235](../src/render/PaletteFX.lua#L1235), [1236](../src/render/PaletteFX.lua#L1236), [1238](../src/render/PaletteFX.lua#L1238), [1246](../src/render/PaletteFX.lua#L1246), [1247](../src/render/PaletteFX.lua#L1247), [1250](../src/render/PaletteFX.lua#L1250), [1253](../src/render/PaletteFX.lua#L1253), [1255](../src/render/PaletteFX.lua#L1255), [1257](../src/render/PaletteFX.lua#L1257), [1264](../src/render/PaletteFX.lua#L1264), [1265](../src/render/PaletteFX.lua#L1265), [1268](../src/render/PaletteFX.lua#L1268), [1269](../src/render/PaletteFX.lua#L1269), [1277](../src/render/PaletteFX.lua#L1277), [1283](../src/render/PaletteFX.lua#L1283), [1285](../src/render/PaletteFX.lua#L1285), [1288](../src/render/PaletteFX.lua#L1288), [1305](../src/render/PaletteFX.lua#L1305), [1306](../src/render/PaletteFX.lua#L1306), [1307](../src/render/PaletteFX.lua#L1307), [1315](../src/render/PaletteFX.lua#L1315), [1317](../src/render/PaletteFX.lua#L1317), [1324](../src/render/PaletteFX.lua#L1324), [1326](../src/render/PaletteFX.lua#L1326), [1328](../src/render/PaletteFX.lua#L1328), [1330](../src/render/PaletteFX.lua#L1330), [1337](../src/render/PaletteFX.lua#L1337), [1338](../src/render/PaletteFX.lua#L1338), [1339](../src/render/PaletteFX.lua#L1339), [1341](../src/render/PaletteFX.lua#L1341), [1345](../src/render/PaletteFX.lua#L1345), [1346](../src/render/PaletteFX.lua#L1346), [1357](../src/render/PaletteFX.lua#L1357), [1362](../src/render/PaletteFX.lua#L1362), [1363](../src/render/PaletteFX.lua#L1363), [1369](../src/render/PaletteFX.lua#L1369), [1370](../src/render/PaletteFX.lua#L1370), [1371](../src/render/PaletteFX.lua#L1371), [1374](../src/render/PaletteFX.lua#L1374), [1377](../src/render/PaletteFX.lua#L1377), [1378](../src/render/PaletteFX.lua#L1378), [1415](../src/render/PaletteFX.lua#L1415), [1419](../src/render/PaletteFX.lua#L1419), [1426](../src/render/PaletteFX.lua#L1426), [1430](../src/render/PaletteFX.lua#L1430), [1432](../src/render/PaletteFX.lua#L1432), [1433](../src/render/PaletteFX.lua#L1433), [1440](../src/render/PaletteFX.lua#L1440), [1443](../src/render/PaletteFX.lua#L1443), [1447](../src/render/PaletteFX.lua#L1447) |
| `src/render/PlayerPalette.lua` | SpriteRenderer | [56](../src/render/PlayerPalette.lua#L56) |
| `src/render/Renderer.lua` | PaletteFX | [12](../src/render/Renderer.lua#L12), [382](../src/render/Renderer.lua#L382), [383](../src/render/Renderer.lua#L383), [386](../src/render/Renderer.lua#L386), [387](../src/render/Renderer.lua#L387), [510](../src/render/Renderer.lua#L510), [516](../src/render/Renderer.lua#L516), [538](../src/render/Renderer.lua#L538), [551](../src/render/Renderer.lua#L551), [635](../src/render/Renderer.lua#L635), [646](../src/render/Renderer.lua#L646), [706](../src/render/Renderer.lua#L706), [791](../src/render/Renderer.lua#L791), [800](../src/render/Renderer.lua#L800), [801](../src/render/Renderer.lua#L801), [816](../src/render/Renderer.lua#L816), [817](../src/render/Renderer.lua#L817), [830](../src/render/Renderer.lua#L830), [1011](../src/render/Renderer.lua#L1011), [1012](../src/render/Renderer.lua#L1012), [1063](../src/render/Renderer.lua#L1063), [1152](../src/render/Renderer.lua#L1152), [1282](../src/render/Renderer.lua#L1282), [1289](../src/render/Renderer.lua#L1289), [1295](../src/render/Renderer.lua#L1295), [1615](../src/render/Renderer.lua#L1615) |
| `src/render/SpriteRenderer.lua` | SpriteRenderer | [11](../src/render/SpriteRenderer.lua#L11), [12](../src/render/SpriteRenderer.lua#L12), [79](../src/render/SpriteRenderer.lua#L79), [87](../src/render/SpriteRenderer.lua#L87), [92](../src/render/SpriteRenderer.lua#L92), [108](../src/render/SpriteRenderer.lua#L108), [109](../src/render/SpriteRenderer.lua#L109), [110](../src/render/SpriteRenderer.lua#L110), [117](../src/render/SpriteRenderer.lua#L117), [118](../src/render/SpriteRenderer.lua#L118), [195](../src/render/SpriteRenderer.lua#L195), [204](../src/render/SpriteRenderer.lua#L204), [222](../src/render/SpriteRenderer.lua#L222), [263](../src/render/SpriteRenderer.lua#L263), [305](../src/render/SpriteRenderer.lua#L305), [313](../src/render/SpriteRenderer.lua#L313), [396](../src/render/SpriteRenderer.lua#L396), [400](../src/render/SpriteRenderer.lua#L400), [467](../src/render/SpriteRenderer.lua#L467), [479](../src/render/SpriteRenderer.lua#L479), [483](../src/render/SpriteRenderer.lua#L483), [510](../src/render/SpriteRenderer.lua#L510), [572](../src/render/SpriteRenderer.lua#L572), [605](../src/render/SpriteRenderer.lua#L605), [648](../src/render/SpriteRenderer.lua#L648), [660](../src/render/SpriteRenderer.lua#L660), [679](../src/render/SpriteRenderer.lua#L679) |
| `src/render/SpriteRenderer.lua` | TileRenderer | [649](../src/render/SpriteRenderer.lua#L649), [650](../src/render/SpriteRenderer.lua#L650), [651](../src/render/SpriteRenderer.lua#L651) |
| `src/render/SpriteRenderer.lua` | PaletteFX | [7](../src/render/SpriteRenderer.lua#L7), [52](../src/render/SpriteRenderer.lua#L52), [53](../src/render/SpriteRenderer.lua#L53), [230](../src/render/SpriteRenderer.lua#L230), [233](../src/render/SpriteRenderer.lua#L233), [234](../src/render/SpriteRenderer.lua#L234), [236](../src/render/SpriteRenderer.lua#L236), [237](../src/render/SpriteRenderer.lua#L237), [238](../src/render/SpriteRenderer.lua#L238), [240](../src/render/SpriteRenderer.lua#L240), [249](../src/render/SpriteRenderer.lua#L249), [252](../src/render/SpriteRenderer.lua#L252), [271](../src/render/SpriteRenderer.lua#L271), [272](../src/render/SpriteRenderer.lua#L272), [275](../src/render/SpriteRenderer.lua#L275), [276](../src/render/SpriteRenderer.lua#L276), [277](../src/render/SpriteRenderer.lua#L277), [281](../src/render/SpriteRenderer.lua#L281), [283](../src/render/SpriteRenderer.lua#L283), [284](../src/render/SpriteRenderer.lua#L284), [287](../src/render/SpriteRenderer.lua#L287), [320](../src/render/SpriteRenderer.lua#L320), [321](../src/render/SpriteRenderer.lua#L321), [328](../src/render/SpriteRenderer.lua#L328), [329](../src/render/SpriteRenderer.lua#L329), [335](../src/render/SpriteRenderer.lua#L335), [339](../src/render/SpriteRenderer.lua#L339), [341](../src/render/SpriteRenderer.lua#L341), [348](../src/render/SpriteRenderer.lua#L348), [351](../src/render/SpriteRenderer.lua#L351), [406](../src/render/SpriteRenderer.lua#L406), [601](../src/render/SpriteRenderer.lua#L601), [663](../src/render/SpriteRenderer.lua#L663), [664](../src/render/SpriteRenderer.lua#L664), [665](../src/render/SpriteRenderer.lua#L665), [667](../src/render/SpriteRenderer.lua#L667), [668](../src/render/SpriteRenderer.lua#L668), [670](../src/render/SpriteRenderer.lua#L670) |
| `src/render/StadiumArt.lua` | PaletteFX | [158](../src/render/StadiumArt.lua#L158) |
| `src/render/TileRenderer.lua` | TileRenderer | [19](../src/render/TileRenderer.lua#L19), [20](../src/render/TileRenderer.lua#L20), [31](../src/render/TileRenderer.lua#L31), [32](../src/render/TileRenderer.lua#L32), [36](../src/render/TileRenderer.lua#L36), [43](../src/render/TileRenderer.lua#L43), [45](../src/render/TileRenderer.lua#L45), [47](../src/render/TileRenderer.lua#L47), [50](../src/render/TileRenderer.lua#L50), [53](../src/render/TileRenderer.lua#L53), [54](../src/render/TileRenderer.lua#L54), [56](../src/render/TileRenderer.lua#L56), [59](../src/render/TileRenderer.lua#L59), [60](../src/render/TileRenderer.lua#L60), [61](../src/render/TileRenderer.lua#L61), [67](../src/render/TileRenderer.lua#L67), [69](../src/render/TileRenderer.lua#L69), [73](../src/render/TileRenderer.lua#L73), [74](../src/render/TileRenderer.lua#L74), [77](../src/render/TileRenderer.lua#L77), [78](../src/render/TileRenderer.lua#L78), [101](../src/render/TileRenderer.lua#L101), [139](../src/render/TileRenderer.lua#L139), [161](../src/render/TileRenderer.lua#L161), [177](../src/render/TileRenderer.lua#L177), [191](../src/render/TileRenderer.lua#L191), [202](../src/render/TileRenderer.lua#L202), [229](../src/render/TileRenderer.lua#L229), [398](../src/render/TileRenderer.lua#L398), [399](../src/render/TileRenderer.lua#L399), [402](../src/render/TileRenderer.lua#L402), [403](../src/render/TileRenderer.lua#L403), [407](../src/render/TileRenderer.lua#L407), [416](../src/render/TileRenderer.lua#L416), [440](../src/render/TileRenderer.lua#L440), [448](../src/render/TileRenderer.lua#L448), [565](../src/render/TileRenderer.lua#L565), [643](../src/render/TileRenderer.lua#L643), [678](../src/render/TileRenderer.lua#L678), [713](../src/render/TileRenderer.lua#L713), [757](../src/render/TileRenderer.lua#L757), [770](../src/render/TileRenderer.lua#L770), [827](../src/render/TileRenderer.lua#L827), [835](../src/render/TileRenderer.lua#L835), [897](../src/render/TileRenderer.lua#L897), [966](../src/render/TileRenderer.lua#L966), [969](../src/render/TileRenderer.lua#L969), [978](../src/render/TileRenderer.lua#L978), [987](../src/render/TileRenderer.lua#L987), [1015](../src/render/TileRenderer.lua#L1015), [1192](../src/render/TileRenderer.lua#L1192), [1428](../src/render/TileRenderer.lua#L1428), [1447](../src/render/TileRenderer.lua#L1447), [1462](../src/render/TileRenderer.lua#L1462), [1475](../src/render/TileRenderer.lua#L1475), [1479](../src/render/TileRenderer.lua#L1479), [1480](../src/render/TileRenderer.lua#L1480), [1519](../src/render/TileRenderer.lua#L1519), [1580](../src/render/TileRenderer.lua#L1580), [1594](../src/render/TileRenderer.lua#L1594), [1642](../src/render/TileRenderer.lua#L1642), [1647](../src/render/TileRenderer.lua#L1647), [1656](../src/render/TileRenderer.lua#L1656), [1790](../src/render/TileRenderer.lua#L1790), [1799](../src/render/TileRenderer.lua#L1799), [1835](../src/render/TileRenderer.lua#L1835), [1919](../src/render/TileRenderer.lua#L1919), [1938](../src/render/TileRenderer.lua#L1938), [1951](../src/render/TileRenderer.lua#L1951), [1967](../src/render/TileRenderer.lua#L1967), [1975](../src/render/TileRenderer.lua#L1975), [1992](../src/render/TileRenderer.lua#L1992), [2001](../src/render/TileRenderer.lua#L2001), [2064](../src/render/TileRenderer.lua#L2064), [2188](../src/render/TileRenderer.lua#L2188), [2241](../src/render/TileRenderer.lua#L2241), [2271](../src/render/TileRenderer.lua#L2271), [2283](../src/render/TileRenderer.lua#L2283), [2323](../src/render/TileRenderer.lua#L2323), [2331](../src/render/TileRenderer.lua#L2331), [2346](../src/render/TileRenderer.lua#L2346), [2371](../src/render/TileRenderer.lua#L2371), [2382](../src/render/TileRenderer.lua#L2382), [2389](../src/render/TileRenderer.lua#L2389), [2431](../src/render/TileRenderer.lua#L2431), [2459](../src/render/TileRenderer.lua#L2459), [2482](../src/render/TileRenderer.lua#L2482), [2490](../src/render/TileRenderer.lua#L2490), [2528](../src/render/TileRenderer.lua#L2528), [2532](../src/render/TileRenderer.lua#L2532), [2539](../src/render/TileRenderer.lua#L2539) |
| `src/render/TileRenderer.lua` | PaletteFX | [15](../src/render/TileRenderer.lua#L15), [492](../src/render/TileRenderer.lua#L492), [582](../src/render/TileRenderer.lua#L582), [589](../src/render/TileRenderer.lua#L589), [597](../src/render/TileRenderer.lua#L597), [598](../src/render/TileRenderer.lua#L598), [622](../src/render/TileRenderer.lua#L622), [634](../src/render/TileRenderer.lua#L634), [760](../src/render/TileRenderer.lua#L760), [762](../src/render/TileRenderer.lua#L762), [777](../src/render/TileRenderer.lua#L777), [785](../src/render/TileRenderer.lua#L785), [839](../src/render/TileRenderer.lua#L839), [857](../src/render/TileRenderer.lua#L857), [899](../src/render/TileRenderer.lua#L899), [1521](../src/render/TileRenderer.lua#L1521), [1530](../src/render/TileRenderer.lua#L1530), [1554](../src/render/TileRenderer.lua#L1554), [1555](../src/render/TileRenderer.lua#L1555), [1671](../src/render/TileRenderer.lua#L1671), [1770](../src/render/TileRenderer.lua#L1770), [1771](../src/render/TileRenderer.lua#L1771), [1843](../src/render/TileRenderer.lua#L1843), [1880](../src/render/TileRenderer.lua#L1880), [1896](../src/render/TileRenderer.lua#L1896), [1957](../src/render/TileRenderer.lua#L1957), [2325](../src/render/TileRenderer.lua#L2325) |
| `src/script/Gen2Commands.lua` | PaletteFX | [1928](../src/script/Gen2Commands.lua#L1928), [1929](../src/script/Gen2Commands.lua#L1929), [1930](../src/script/Gen2Commands.lua#L1930), [1932](../src/script/Gen2Commands.lua#L1932) |
| `src/ui/BagMenu.lua` | PaletteFX | [1115](../src/ui/BagMenu.lua#L1115) |
| `src/ui/BirchSpeech.lua` | PaletteFX | [76](../src/ui/BirchSpeech.lua#L76) |
| `src/ui/DexEntryMenu.lua` | PaletteFX | [22](../src/ui/DexEntryMenu.lua#L22), [162](../src/ui/DexEntryMenu.lua#L162), [229](../src/ui/DexEntryMenu.lua#L229) |
| `src/ui/EvolutionState.lua` | PaletteFX | [22](../src/ui/EvolutionState.lua#L22), [153](../src/ui/EvolutionState.lua#L153) |
| `src/ui/Gen2CardFlip.lua` | PaletteFX | [103](../src/ui/Gen2CardFlip.lua#L103) |
| `src/ui/Gen2Chrome.lua` | PaletteFX | [15](../src/ui/Gen2Chrome.lua#L15), [18](../src/ui/Gen2Chrome.lua#L18), [19](../src/ui/Gen2Chrome.lua#L19), [21](../src/ui/Gen2Chrome.lua#L21), [29](../src/ui/Gen2Chrome.lua#L29), [266](../src/ui/Gen2Chrome.lua#L266) |
| `src/ui/Gen2InitClock.lua` | PaletteFX | [160](../src/ui/Gen2InitClock.lua#L160) |
| `src/ui/Gen2Intro.lua` | PaletteFX | [618](../src/ui/Gen2Intro.lua#L618) |
| `src/ui/Gen2NamePick.lua` | PaletteFX | [84](../src/ui/Gen2NamePick.lua#L84) |
| `src/ui/Gen2Slots.lua` | PaletteFX | [81](../src/ui/Gen2Slots.lua#L81) |
| `src/ui/Gen2TradeAnim.lua` | PaletteFX | [250](../src/ui/Gen2TradeAnim.lua#L250), [583](../src/ui/Gen2TradeAnim.lua#L583), [1299](../src/ui/Gen2TradeAnim.lua#L1299) |
| `src/ui/Gen3BagMenu.lua` | PaletteFX | [153](../src/ui/Gen3BagMenu.lua#L153) |
| `src/ui/Gen3BerryPouch.lua` | PaletteFX | [47](../src/ui/Gen3BerryPouch.lua#L47) |
| `src/ui/Gen3BoxMenu.lua` | PaletteFX | [148](../src/ui/Gen3BoxMenu.lua#L148) |
| `src/ui/Gen3CreditsFRLG.lua` | PaletteFX | [33](../src/ui/Gen3CreditsFRLG.lua#L33) |
| `src/ui/Gen3DexEntry.lua` | PaletteFX | [304](../src/ui/Gen3DexEntry.lua#L304), [354](../src/ui/Gen3DexEntry.lua#L354) |
| `src/ui/Gen3DexSearch.lua` | PaletteFX | [83](../src/ui/Gen3DexSearch.lua#L83) |
| `src/ui/Gen3EvolutionState.lua` | PaletteFX | [57](../src/ui/Gen3EvolutionState.lua#L57), [246](../src/ui/Gen3EvolutionState.lua#L246) |
| `src/ui/Gen3FRLGScenes.lua` | PaletteFX | [38](../src/ui/Gen3FRLGScenes.lua#L38) |
| `src/ui/Gen3HallOfFameFRLG.lua` | PaletteFX | [31](../src/ui/Gen3HallOfFameFRLG.lua#L31) |
| `src/ui/Gen3Intro.lua` | PaletteFX | [310](../src/ui/Gen3Intro.lua#L310) |
| `src/ui/Gen3IntroFRLG.lua` | PaletteFX | [111](../src/ui/Gen3IntroFRLG.lua#L111) |
| `src/ui/Gen3ItemPcFRLG.lua` | PaletteFX | [86](../src/ui/Gen3ItemPcFRLG.lua#L86) |
| `src/ui/Gen3MainMenu.lua` | PaletteFX | [81](../src/ui/Gen3MainMenu.lua#L81) |
| `src/ui/Gen3OakSpeechFRLG.lua` | PaletteFX | [54](../src/ui/Gen3OakSpeechFRLG.lua#L54) |
| `src/ui/Gen3Options.lua` | PaletteFX | [60](../src/ui/Gen3Options.lua#L60) |
| `src/ui/Gen3PartyMenu.lua` | PaletteFX | [122](../src/ui/Gen3PartyMenu.lua#L122) |
| `src/ui/Gen3PokeblockFeed.lua` | PaletteFX | [62](../src/ui/Gen3PokeblockFeed.lua#L62), [242](../src/ui/Gen3PokeblockFeed.lua#L242) |
| `src/ui/Gen3Pokedex.lua` | PaletteFX | [29](../src/ui/Gen3Pokedex.lua#L29), [98](../src/ui/Gen3Pokedex.lua#L98), [481](../src/ui/Gen3Pokedex.lua#L481), [531](../src/ui/Gen3Pokedex.lua#L531), [580](../src/ui/Gen3Pokedex.lua#L580), [660](../src/ui/Gen3Pokedex.lua#L660) |
| `src/ui/Gen3PokedexFRLG.lua` | PaletteFX | [34](../src/ui/Gen3PokedexFRLG.lua#L34) |
| `src/ui/Gen3Pokenav.lua` | PaletteFX | [117](../src/ui/Gen3Pokenav.lua#L117), [850](../src/ui/Gen3Pokenav.lua#L850) |
| `src/ui/Gen3ShopMenu.lua` | PaletteFX | [118](../src/ui/Gen3ShopMenu.lua#L118) |
| `src/ui/Gen3StartMenu.lua` | PaletteFX | [79](../src/ui/Gen3StartMenu.lua#L79) |
| `src/ui/Gen3TMCase.lua` | PaletteFX | [60](../src/ui/Gen3TMCase.lua#L60) |
| `src/ui/Gen3TeachyTV.lua` | SpriteRenderer | [817](../src/ui/Gen3TeachyTV.lua#L817) |
| `src/ui/Gen3TeachyTV.lua` | PaletteFX | [71](../src/ui/Gen3TeachyTV.lua#L71) |
| `src/ui/Gen3Title.lua` | PaletteFX | [183](../src/ui/Gen3Title.lua#L183) |
| `src/ui/Gen3TitleFRLG.lua` | PaletteFX | [28](../src/ui/Gen3TitleFRLG.lua#L28) |
| `src/ui/Gen3TradeAnim.lua` | PaletteFX | [378](../src/ui/Gen3TradeAnim.lua#L378) |
| `src/ui/Gen3TrainerCard.lua` | PaletteFX | [114](../src/ui/Gen3TrainerCard.lua#L114) |
| `src/ui/Gen3WallClock.lua` | PaletteFX | [53](../src/ui/Gen3WallClock.lua#L53) |
| `src/ui/Gen4BagMenu.lua` | PaletteFX | [220](../src/ui/Gen4BagMenu.lua#L220) |
| `src/ui/Gen4BoxMenu.lua` | PaletteFX | [57](../src/ui/Gen4BoxMenu.lua#L57) |
| `src/ui/Gen4EggHatchState.lua` | PaletteFX | [117](../src/ui/Gen4EggHatchState.lua#L117) |
| `src/ui/Gen4EvolutionState.lua` | PaletteFX | [138](../src/ui/Gen4EvolutionState.lua#L138) |
| `src/ui/Gen4FrontierScene.lua` | SpriteRenderer | [112](../src/ui/Gen4FrontierScene.lua#L112), [115](../src/ui/Gen4FrontierScene.lua#L115) |
| `src/ui/Gen4Intro.lua` | PaletteFX | [30](../src/ui/Gen4Intro.lua#L30) |
| `src/ui/Gen4MainMenu.lua` | PaletteFX | [74](../src/ui/Gen4MainMenu.lua#L74) |
| `src/ui/Gen4NamingScreen.lua` | PaletteFX | [166](../src/ui/Gen4NamingScreen.lua#L166) |
| `src/ui/Gen4Options.lua` | PaletteFX | [88](../src/ui/Gen4Options.lua#L88) |
| `src/ui/Gen4PartyMenu.lua` | PaletteFX | [114](../src/ui/Gen4PartyMenu.lua#L114) |
| `src/ui/Gen4Pokedex.lua` | PaletteFX | [88](../src/ui/Gen4Pokedex.lua#L88) |
| `src/ui/Gen4RowanIntro.lua` | PaletteFX | [187](../src/ui/Gen4RowanIntro.lua#L187) |
| `src/ui/Gen4ShopMenu.lua` | PaletteFX | [71](../src/ui/Gen4ShopMenu.lua#L71) |
| `src/ui/Gen4StarterSelect.lua` | PaletteFX | [231](../src/ui/Gen4StarterSelect.lua#L231) |
| `src/ui/Gen4StorageMenu.lua` | PaletteFX | [27](../src/ui/Gen4StorageMenu.lua#L27) |
| `src/ui/Gen4SummaryMenu.lua` | PaletteFX | [173](../src/ui/Gen4SummaryMenu.lua#L173) |
| `src/ui/Gen4Title.lua` | PaletteFX | [149](../src/ui/Gen4Title.lua#L149) |
| `src/ui/Gen4TrainerCard.lua` | PaletteFX | [243](../src/ui/Gen4TrainerCard.lua#L243) |
| `src/ui/Gen5JuniperIntro.lua` | PaletteFX | [11](../src/ui/Gen5JuniperIntro.lua#L11) |
| `src/ui/Gen5NamingScreen.lua` | PaletteFX | [60](../src/ui/Gen5NamingScreen.lua#L60) |
| `src/ui/Gen5Opening.lua` | PaletteFX | [20](../src/ui/Gen5Opening.lua#L20) |
| `src/ui/Gen5Title.lua` | PaletteFX | [52](../src/ui/Gen5Title.lua#L52) |
| `src/ui/HallOfFame.lua` | PaletteFX | [24](../src/ui/HallOfFame.lua#L24) |
| `src/ui/IntroMovie.lua` | PaletteFX | [44](../src/ui/IntroMovie.lua#L44) |
| `src/ui/ListMenu.lua` | PaletteFX | [16](../src/ui/ListMenu.lua#L16), [279](../src/ui/ListMenu.lua#L279) |
| `src/ui/NamingScreen.lua` | PaletteFX | [133](../src/ui/NamingScreen.lua#L133), [375](../src/ui/NamingScreen.lua#L375) |
| `src/ui/OakSpeech.lua` | PaletteFX | [50](../src/ui/OakSpeech.lua#L50), [997](../src/ui/OakSpeech.lua#L997), [1006](../src/ui/OakSpeech.lua#L1006) |
| `src/ui/OptionsMenu.lua` | TileRenderer | [19](../src/ui/OptionsMenu.lua#L19), [452](../src/ui/OptionsMenu.lua#L452), [456](../src/ui/OptionsMenu.lua#L456), [463](../src/ui/OptionsMenu.lua#L463) |
| `src/ui/OptionsMenu.lua` | PaletteFX | [13](../src/ui/OptionsMenu.lua#L13), [42](../src/ui/OptionsMenu.lua#L42), [110](../src/ui/OptionsMenu.lua#L110), [111](../src/ui/OptionsMenu.lua#L111), [376](../src/ui/OptionsMenu.lua#L376), [377](../src/ui/OptionsMenu.lua#L377), [382](../src/ui/OptionsMenu.lua#L382), [384](../src/ui/OptionsMenu.lua#L384), [385](../src/ui/OptionsMenu.lua#L385), [386](../src/ui/OptionsMenu.lua#L386) |
| `src/ui/PartyMenu.lua` | PaletteFX | [48](../src/ui/PartyMenu.lua#L48), [180](../src/ui/PartyMenu.lua#L180), [980](../src/ui/PartyMenu.lua#L980), [988](../src/ui/PartyMenu.lua#L988), [989](../src/ui/PartyMenu.lua#L989) |
| `src/ui/PicBox.lua` | PaletteFX | [166](../src/ui/PicBox.lua#L166) |
| `src/ui/PokedexMenu.lua` | PaletteFX | [25](../src/ui/PokedexMenu.lua#L25) |
| `src/ui/PokedexUnownMode.lua` | PaletteFX | [41](../src/ui/PokedexUnownMode.lua#L41), [209](../src/ui/PokedexUnownMode.lua#L209) |
| `src/ui/PokegearMenu.lua` | PaletteFX | [971](../src/ui/PokegearMenu.lua#L971), [1028](../src/ui/PokegearMenu.lua#L1028) |
| `src/ui/PrismCustomization.lua` | SpriteRenderer | [163](../src/ui/PrismCustomization.lua#L163) |
| `src/ui/PrismCustomization.lua` | PaletteFX | [319](../src/ui/PrismCustomization.lua#L319) |
| `src/ui/ShaderPresetMenu.lua` | PaletteFX | [18](../src/ui/ShaderPresetMenu.lua#L18) |
| `src/ui/SlotMachine.lua` | PaletteFX | [62](../src/ui/SlotMachine.lua#L62) |
| `src/ui/SummaryMenu.lua` | PaletteFX | [74](../src/ui/SummaryMenu.lua#L74), [312](../src/ui/SummaryMenu.lua#L312), [429](../src/ui/SummaryMenu.lua#L429), [572](../src/ui/SummaryMenu.lua#L572), [599](../src/ui/SummaryMenu.lua#L599), [663](../src/ui/SummaryMenu.lua#L663) |
| `src/ui/SurfingMinigame.lua` | PaletteFX | [227](../src/ui/SurfingMinigame.lua#L227) |
| `src/ui/TitleState.lua` | PaletteFX | [59](../src/ui/TitleState.lua#L59), [133](../src/ui/TitleState.lua#L133) |
| `src/ui/TownMap.lua` | PaletteFX | [34](../src/ui/TownMap.lua#L34), [460](../src/ui/TownMap.lua#L460) |
| `src/ui/TradeAnim.lua` | PaletteFX | [102](../src/ui/TradeAnim.lua#L102), [722](../src/ui/TradeAnim.lua#L722), [964](../src/ui/TradeAnim.lua#L964) |
| `src/ui/TradeAnimKit.lua` | PaletteFX | [98](../src/ui/TradeAnimKit.lua#L98), [115](../src/ui/TradeAnimKit.lua#L115) |
| `src/ui/TrainerCard.lua` | PaletteFX | [31](../src/ui/TrainerCard.lua#L31), [232](../src/ui/TrainerCard.lua#L232), [278](../src/ui/TrainerCard.lua#L278), [293](../src/ui/TrainerCard.lua#L293) |
| `src/ui/UnownPuzzle.lua` | PaletteFX | [22](../src/ui/UnownPuzzle.lua#L22), [205](../src/ui/UnownPuzzle.lua#L205) |
| `src/ui/YellowIntro.lua` | PaletteFX | [287](../src/ui/YellowIntro.lua#L287) |
| `src/world/Gen3FieldMove.lua` | PaletteFX | [399](../src/world/Gen3FieldMove.lua#L399) |
| `src/world/Gen4BerryPatches.lua` | SpriteRenderer | [123](../src/world/Gen4BerryPatches.lua#L123), [136](../src/world/Gen4BerryPatches.lua#L136) |
| `src/world/Gen4FishingTask.lua` | SpriteRenderer | [160](../src/world/Gen4FishingTask.lua#L160), [164](../src/world/Gen4FishingTask.lua#L164) |
| `src/world/Gen4HMCutIn.lua` | PaletteFX | [327](../src/world/Gen4HMCutIn.lua#L327) |
| `src/world/HgssFollowMon.lua` | SpriteRenderer | [191](../src/world/HgssFollowMon.lua#L191), [192](../src/world/HgssFollowMon.lua#L192) |
| `src/world/MapLoader.lua` | TileRenderer | [16](../src/world/MapLoader.lua#L16), [153](../src/world/MapLoader.lua#L153), [156](../src/world/MapLoader.lua#L156) |
| `src/world/NPC-1.lua` | SpriteRenderer | [7](../src/world/NPC-1.lua#L7), [473](../src/world/NPC-1.lua#L473), [709](../src/world/NPC-1.lua#L709) |
| `src/world/NPC.lua` | SpriteRenderer | [7](../src/world/NPC.lua#L7), [478](../src/world/NPC.lua#L478), [720](../src/world/NPC.lua#L720) |
| `src/world/OverworldController.lua` | SpriteRenderer | [50](../src/world/OverworldController.lua#L50), [61](../src/world/OverworldController.lua#L61), [62](../src/world/OverworldController.lua#L62), [17198](../src/world/OverworldController.lua#L17198), [17340](../src/world/OverworldController.lua#L17340), [17984](../src/world/OverworldController.lua#L17984) |
| `src/world/OverworldController.lua` | TileRenderer | [50](../src/world/OverworldController.lua#L50), [52](../src/world/OverworldController.lua#L52), [53](../src/world/OverworldController.lua#L53), [16650](../src/world/OverworldController.lua#L16650), [16651](../src/world/OverworldController.lua#L16651) |
| `src/world/OverworldController.lua` | PaletteFX | [28](../src/world/OverworldController.lua#L28), [249](../src/world/OverworldController.lua#L249), [1367](../src/world/OverworldController.lua#L1367), [1369](../src/world/OverworldController.lua#L1369), [1378](../src/world/OverworldController.lua#L1378), [1379](../src/world/OverworldController.lua#L1379), [1380](../src/world/OverworldController.lua#L1380), [2530](../src/world/OverworldController.lua#L2530), [2532](../src/world/OverworldController.lua#L2532), [2534](../src/world/OverworldController.lua#L2534), [2535](../src/world/OverworldController.lua#L2535), [2621](../src/world/OverworldController.lua#L2621), [2624](../src/world/OverworldController.lua#L2624), [2626](../src/world/OverworldController.lua#L2626), [2627](../src/world/OverworldController.lua#L2627), [2629](../src/world/OverworldController.lua#L2629), [2636](../src/world/OverworldController.lua#L2636), [2640](../src/world/OverworldController.lua#L2640), [2663](../src/world/OverworldController.lua#L2663), [2664](../src/world/OverworldController.lua#L2664), [2682](../src/world/OverworldController.lua#L2682), [2686](../src/world/OverworldController.lua#L2686), [2692](../src/world/OverworldController.lua#L2692), [2719](../src/world/OverworldController.lua#L2719), [2720](../src/world/OverworldController.lua#L2720), [16516](../src/world/OverworldController.lua#L16516), [16517](../src/world/OverworldController.lua#L16517), [16519](../src/world/OverworldController.lua#L16519), [17506](../src/world/OverworldController.lua#L17506), [17512](../src/world/OverworldController.lua#L17512), [17513](../src/world/OverworldController.lua#L17513), [17515](../src/world/OverworldController.lua#L17515), [17516](../src/world/OverworldController.lua#L17516), [17978](../src/world/OverworldController.lua#L17978), [18057](../src/world/OverworldController.lua#L18057), [18282](../src/world/OverworldController.lua#L18282), [18430](../src/world/OverworldController.lua#L18430), [18433](../src/world/OverworldController.lua#L18433), [18434](../src/world/OverworldController.lua#L18434), [18455](../src/world/OverworldController.lua#L18455), [18457](../src/world/OverworldController.lua#L18457), [18583](../src/world/OverworldController.lua#L18583), [18584](../src/world/OverworldController.lua#L18584), [19138](../src/world/OverworldController.lua#L19138) |
| `src/world/Player.lua` | SpriteRenderer | [9](../src/world/Player.lua#L9), [106](../src/world/Player.lua#L106), [111](../src/world/Player.lua#L111), [309](../src/world/Player.lua#L309), [310](../src/world/Player.lua#L310), [378](../src/world/Player.lua#L378), [386](../src/world/Player.lua#L386), [396](../src/world/Player.lua#L396), [404](../src/world/Player.lua#L404) |
| `src/world/RemotePlayers.lua` | SpriteRenderer | [82](../src/world/RemotePlayers.lua#L82) |
| `src/world/RemotePlayers.lua` | PaletteFX | [57](../src/world/RemotePlayers.lua#L57) |
| `mods/DRAMATIC_SHAPE/lib/BattleScene.lua` | TileRenderer | [536](../mods/DRAMATIC_SHAPE/lib/BattleScene.lua#L536) |
| `mods/DRAMATIC_SHAPE/lib/BattleScene.lua` | PaletteFX | [46](../mods/DRAMATIC_SHAPE/lib/BattleScene.lua#L46), [164](../mods/DRAMATIC_SHAPE/lib/BattleScene.lua#L164) |
| `mods/DRAMATIC_SHAPE/lib/DayNight.lua` | PaletteFX | [50](../mods/DRAMATIC_SHAPE/lib/DayNight.lua#L50) |
| `mods/DRAMATIC_SHAPE/lib/EngineSheets.lua` | TileRenderer | [6](../mods/DRAMATIC_SHAPE/lib/EngineSheets.lua#L6) |
| `mods/DRAMATIC_SHAPE/lib/Gen3.lua` | TileRenderer | [6645](../mods/DRAMATIC_SHAPE/lib/Gen3.lua#L6645), [6646](../mods/DRAMATIC_SHAPE/lib/Gen3.lua#L6646), [6648](../mods/DRAMATIC_SHAPE/lib/Gen3.lua#L6648) |
| `mods/DRAMATIC_SHAPE/lib/Sky.lua` | PaletteFX | [54](../mods/DRAMATIC_SHAPE/lib/Sky.lua#L54), [104](../mods/DRAMATIC_SHAPE/lib/Sky.lua#L104), [439](../mods/DRAMATIC_SHAPE/lib/Sky.lua#L439) |
| `mods/DRAMATIC_SHAPE/lib/Structures.lua` | TileRenderer | [12323](../mods/DRAMATIC_SHAPE/lib/Structures.lua#L12323), [12324](../mods/DRAMATIC_SHAPE/lib/Structures.lua#L12324), [12413](../mods/DRAMATIC_SHAPE/lib/Structures.lua#L12413), [31273](../mods/DRAMATIC_SHAPE/lib/Structures.lua#L31273), [31274](../mods/DRAMATIC_SHAPE/lib/Structures.lua#L31274) |
| `mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua` | TileRenderer | [34](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L34), [174](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L174), [312](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L312), [418](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L418), [481](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L481), [510](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L510), [511](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L511), [556](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L556), [558](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L558), [566](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L566), [567](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L567), [572](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L572), [872](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L872) |
| `mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua` | PaletteFX | [35](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L35), [404](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L404), [428](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L428), [436](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L436), [437](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L437) |
| `mods/DRAMATIC_SHAPE/lib/TileShape.lua` | TileRenderer | [676](../mods/DRAMATIC_SHAPE/lib/TileShape.lua#L676), [677](../mods/DRAMATIC_SHAPE/lib/TileShape.lua#L677) |
| `mods/DRAMATIC_SHAPE/lib/VoxelScene.lua` | SpriteRenderer | [608](../mods/DRAMATIC_SHAPE/lib/VoxelScene.lua#L608) |
| `mods/DRAMATIC_SHAPE/lib/VoxelScene.lua` | PaletteFX | [51](../mods/DRAMATIC_SHAPE/lib/VoxelScene.lua#L51), [73](../mods/DRAMATIC_SHAPE/lib/VoxelScene.lua#L73), [115](../mods/DRAMATIC_SHAPE/lib/VoxelScene.lua#L115), [2706](../mods/DRAMATIC_SHAPE/lib/VoxelScene.lua#L2706) |
| `mods/DRAMATIC_SHAPE/main.lua` | TileRenderer | [362](../mods/DRAMATIC_SHAPE/main.lua#L362), [363](../mods/DRAMATIC_SHAPE/main.lua#L363) |

### Image construction and pixel callbacks

All `mapPixel` and qualified `newImage` references in engine Lua and DRAMATIC_SHAPE are retained, including capability checks and import-time sites. PNG loads are not palette bakes. Gen 3 sections inside shared files remain excluded by X5; the table above identifies the Gen 1/2 functions.

| Site | Operation | Reason / boundary |
| --- | --- | --- |
| [src/battle/AnimPlayer.lua:635](../src/battle/AnimPlayer.lua#L635) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/AnimPlayer.lua:636](../src/battle/AnimPlayer.lua#L636) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/BattleState.lua:676](../src/battle/BattleState.lua#L676) | mapPixel | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:704](../src/battle/BattleState.lua#L704) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:11293](../src/battle/BattleState.lua#L11293) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:11384](../src/battle/BattleState.lua#L11384) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/Gen2AnimPlayer.lua:861](../src/battle/Gen2AnimPlayer.lua#L861) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/Gen2AnimPlayer.lua:862](../src/battle/Gen2AnimPlayer.lua#L862) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/Gen4Battle.lua:3100](../src/battle/Gen4Battle.lua#L3100) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/compat/gen1/AtlasUpload.lua:8](../src/compat/gen1/AtlasUpload.lua#L8) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/FieldEffectRuntime.lua:121](../src/compat/gen1/FieldEffectRuntime.lua#L121) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:187](../src/compat/gen1/SpriteRuntime.lua#L187) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:272](../src/compat/gen1/SpriteRuntime.lua#L272) | mapPixel | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:287](../src/compat/gen1/SpriteRuntime.lua#L287) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/core/TouchControls.lua:214](../src/core/TouchControls.lua#L214) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/core/game3/pokemon.lua:183](../src/core/game3/pokemon.lua#L183) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/core/game3/trainer_pic.lua:25](../src/core/game3/trainer_pic.lua#L25) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/import/AccountWorkspace.lua:32](../src/import/AccountWorkspace.lua#L32) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ArenaPresentation.lua:8](../src/import/ArenaPresentation.lua#L8) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/BankWorkspace.lua:130](../src/import/BankWorkspace.lua#L130) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/CartDesigner.lua:74](../src/import/CartDesigner.lua#L74) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/CartDesigner.lua:102](../src/import/CartDesigner.lua#L102) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/DeveloperWorkspace.lua:27](../src/import/DeveloperWorkspace.lua#L27) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/Gen5MoveAnimData.lua:295](../src/import/Gen5MoveAnimData.lua#L295) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ImageWriter.lua:70](../src/import/ImageWriter.lua#L70) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ImageWriter.lua:102](../src/import/ImageWriter.lua#L102) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherArt.lua:114](../src/import/LauncherArt.lua#L114) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherCobblemon.lua:20](../src/import/LauncherCobblemon.lua#L20) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherCommunity.lua:461](../src/import/LauncherCommunity.lua#L461) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherJourney.lua:16](../src/import/LauncherJourney.lua#L16) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherSidebar.lua:1023](../src/import/LauncherSidebar.lua#L1023) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomExtractorGen2.lua:2291](../src/import/RomExtractorGen2.lua#L2291) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2968](../src/import/RomImporter.lua#L2968) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2969](../src/import/RomImporter.lua#L2969) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2970](../src/import/RomImporter.lua#L2970) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2973](../src/import/RomImporter.lua#L2973) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2974](../src/import/RomImporter.lua#L2974) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:5645](../src/import/RomImporter.lua#L5645) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:11336](../src/import/RomImporter.lua#L11336) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/mods/AssetTransform.lua:73](../src/mods/AssetTransform.lua#L73) | mapPixel | Cached screen/effect artwork PNG load; no world palette bake |
| [src/mods/Loader.lua:1232](../src/mods/Loader.lua#L1232) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/pokemon/Gen5MonAnimPlayer.lua:28](../src/pokemon/Gen5MonAnimPlayer.lua#L28) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/pokemon/PicAnim.lua:98](../src/pokemon/PicAnim.lua#L98) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/pokewalker/WalkerArt.lua:154](../src/pokewalker/WalkerArt.lua#L154) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/render/Assets.lua:55](../src/render/Assets.lua#L55) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/Assets.lua:66](../src/render/Assets.lua#L66) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/Assets.lua:70](../src/render/Assets.lua#L70) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/FontHD.lua:138](../src/render/FontHD.lua#L138) | newImage | Font raster/atlas upload; outside palette switch |
| [src/render/GbcColorCorrection.lua:100](../src/render/GbcColorCorrection.lua#L100) | newImage | Independent display correction LUT; preserve |
| [src/render/Gen3BadgeArt.lua:32](../src/render/Gen3BadgeArt.lua#L32) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3BadgeArt.lua:76](../src/render/Gen3BadgeArt.lua#L76) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3RegionMapArt.lua:36](../src/render/Gen3RegionMapArt.lua#L36) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3RegionMapArt.lua:79](../src/render/Gen3RegionMapArt.lua#L79) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3RegionMapArt.lua:127](../src/render/Gen3RegionMapArt.lua#L127) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3Scene.lua:76](../src/render/Gen3Scene.lua#L76) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3Scene.lua:264](../src/render/Gen3Scene.lua#L264) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen3Scene.lua:383](../src/render/Gen3Scene.lua#L383) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen4BattleTransition.lua:780](../src/render/Gen4BattleTransition.lua#L780) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen4Model.lua:1060](../src/render/Gen4Model.lua#L1060) | mapPixel | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen4Model.lua:1067](../src/render/Gen4Model.lua#L1067) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/HudTiles.lua:204](../src/render/HudTiles.lua#L204) | newImage | Native HUD/OBJ tile raster upload |
| [src/render/PaletteIndex.lua:101](../src/render/PaletteIndex.lua#L101) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/render/ShaderGraph.lua:349](../src/render/ShaderGraph.lua#L349) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/render/SpriteRenderer.lua:60](../src/render/SpriteRenderer.lua#L60) | mapPixel | Cached OBJ palette and color-zero alpha bake |
| [src/render/SpriteRenderer.lua:66](../src/render/SpriteRenderer.lua#L66) | newImage | Cached OBJ palette and color-zero alpha bake |
| [src/render/TileRenderer.lua:254](../src/render/TileRenderer.lua#L254) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:281](../src/render/TileRenderer.lua#L281) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:331](../src/render/TileRenderer.lua#L331) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:389](../src/render/TileRenderer.lua#L389) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:737](../src/render/TileRenderer.lua#L737) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:873](../src/render/TileRenderer.lua#L873) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1280](../src/render/TileRenderer.lua#L1280) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1299](../src/render/TileRenderer.lua#L1299) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1319](../src/render/TileRenderer.lua#L1319) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1709](../src/render/TileRenderer.lua#L1709) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1756](../src/render/TileRenderer.lua#L1756) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1912](../src/render/TileRenderer.lua#L1912) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/ui/BirchSpeech.lua:91](../src/ui/BirchSpeech.lua#L91) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Credits.lua:68](../src/ui/Credits.lua#L68) | newImage | Credits background white-to-alpha bake or plain PNG load |
| [src/ui/Credits.lua:83](../src/ui/Credits.lua#L83) | mapPixel | Credits background white-to-alpha bake or plain PNG load |
| [src/ui/Credits.lua:87](../src/ui/Credits.lua#L87) | newImage | Credits background white-to-alpha bake or plain PNG load |
| [src/ui/Credits.lua:91](../src/ui/Credits.lua#L91) | newImage | Credits background white-to-alpha bake or plain PNG load |
| [src/ui/DexEntryMenu.lua:51](../src/ui/DexEntryMenu.lua#L51) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/EvolutionState.lua:54](../src/ui/EvolutionState.lua#L54) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen2CardFlip.lua:318](../src/ui/Gen2CardFlip.lua#L318) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen2CardFlip.lua:322](../src/ui/Gen2CardFlip.lua#L322) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen2Intro.lua:31](../src/ui/Gen2Intro.lua#L31) | newImage | Intro PNG load and color-zero matte |
| [src/ui/Gen2Intro.lua:202](../src/ui/Gen2Intro.lua#L202) | newImage | Intro PNG load and color-zero matte |
| [src/ui/Gen2Slots.lua:272](../src/ui/Gen2Slots.lua#L272) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen2Slots.lua:276](../src/ui/Gen2Slots.lua#L276) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen2TradeAnim.lua:145](../src/ui/Gen2TradeAnim.lua#L145) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/Gen3BoxMenu.lua:1222](../src/ui/Gen3BoxMenu.lua#L1222) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3DexEntry.lua:142](../src/ui/Gen3DexEntry.lua#L142) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3EvolutionState.lua:87](../src/ui/Gen3EvolutionState.lua#L87) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3EvolutionState.lua:97](../src/ui/Gen3EvolutionState.lua#L97) | mapPixel | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3EvolutionState.lua:101](../src/ui/Gen3EvolutionState.lua#L101) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3OakSpeechFRLG.lua:107](../src/ui/Gen3OakSpeechFRLG.lua#L107) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3PartyMenu.lua:1304](../src/ui/Gen3PartyMenu.lua#L1304) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3PokeblockFeed.lua:98](../src/ui/Gen3PokeblockFeed.lua#L98) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3Pokedex.lua:209](../src/ui/Gen3Pokedex.lua#L209) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3PokedexFRLG.lua:280](../src/ui/Gen3PokedexFRLG.lua#L280) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3StarterSelect.lua:186](../src/ui/Gen3StarterSelect.lua#L186) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3SummaryMenu.lua:260](../src/ui/Gen3SummaryMenu.lua#L260) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3SummaryMenu.lua:303](../src/ui/Gen3SummaryMenu.lua#L303) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3TradeAnim.lua:333](../src/ui/Gen3TradeAnim.lua#L333) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3TradeAnim.lua:334](../src/ui/Gen3TradeAnim.lua#L334) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen3TradeAnim.lua:550](../src/ui/Gen3TradeAnim.lua#L550) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen4ScratchOffCards.lua:213](../src/ui/Gen4ScratchOffCards.lua#L213) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen4TownMap.lua:275](../src/ui/Gen4TownMap.lua#L275) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen4TrainerCard.lua:911](../src/ui/Gen4TrainerCard.lua#L911) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen5EggHatchState.lua:62](../src/ui/Gen5EggHatchState.lua#L62) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/Gen5Opening.lua:92](../src/ui/Gen5Opening.lua#L92) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HallOfFame.lua:57](../src/ui/HallOfFame.lua#L57) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/HgssMartBuy.lua:65](../src/ui/HgssMartBuy.lua#L65) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPennantCapture.lua:779](../src/ui/HgssPennantCapture.lua#L779) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonBlockSmash.lua:649](../src/ui/HgssPokeathlonBlockSmash.lua#L649) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonBlockSmash.lua:695](../src/ui/HgssPokeathlonBlockSmash.lua#L695) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonCirclePush.lua:854](../src/ui/HgssPokeathlonCirclePush.lua#L854) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonCountdown.lua:84](../src/ui/HgssPokeathlonCountdown.lua#L84) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonDiscCatch.lua:878](../src/ui/HgssPokeathlonDiscCatch.lua#L878) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonDiscCatch.lua:923](../src/ui/HgssPokeathlonDiscCatch.lua#L923) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonGoalRoll.lua:1179](../src/ui/HgssPokeathlonGoalRoll.lua#L1179) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonLampJump.lua:765](../src/ui/HgssPokeathlonLampJump.lua#L765) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonRelayRun.lua:644](../src/ui/HgssPokeathlonRelayRun.lua#L644) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonRingDrop.lua:1045](../src/ui/HgssPokeathlonRingDrop.lua#L1045) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonRoomView.lua:67](../src/ui/HgssPokeathlonRoomView.lua#L67) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonSnowThrow.lua:644](../src/ui/HgssPokeathlonSnowThrow.lua#L644) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonSnowThrow.lua:696](../src/ui/HgssPokeathlonSnowThrow.lua#L696) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssPokeathlonTeamInfo.lua:76](../src/ui/HgssPokeathlonTeamInfo.lua#L76) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/HgssSummaryMenu.lua:153](../src/ui/HgssSummaryMenu.lua#L153) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/IntroMovie.lua:133](../src/ui/IntroMovie.lua#L133) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/ListMenu.lua:42](../src/ui/ListMenu.lua#L42) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/ListMenu.lua:300](../src/ui/ListMenu.lua#L300) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/OakSpeech.lua:133](../src/ui/OakSpeech.lua#L133) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/PartyMenu.lua:187](../src/ui/PartyMenu.lua#L187) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:192](../src/ui/PartyMenu.lua#L192) | mapPixel | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:198](../src/ui/PartyMenu.lua#L198) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:218](../src/ui/PartyMenu.lua#L218) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:276](../src/ui/PartyMenu.lua#L276) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:279](../src/ui/PartyMenu.lua#L279) | mapPixel | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:288](../src/ui/PartyMenu.lua#L288) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PartyMenu.lua:343](../src/ui/PartyMenu.lua#L343) | newImage | Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads |
| [src/ui/PicBox.lua:51](../src/ui/PicBox.lua#L51) | newImage | Cached species palette for script picture popup |
| [src/ui/PicBox.lua:56](../src/ui/PicBox.lua#L56) | mapPixel | Cached species palette for script picture popup |
| [src/ui/PicBox.lua:62](../src/ui/PicBox.lua#L62) | newImage | Cached species palette for script picture popup |
| [src/ui/PokedexMenu.lua:223](../src/ui/PokedexMenu.lua#L223) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/PokedexUnownMode.lua:131](../src/ui/PokedexUnownMode.lua#L131) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/PokedexUnownMode.lua:144](../src/ui/PokedexUnownMode.lua#L144) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/PokegearMenu.lua:135](../src/ui/PokegearMenu.lua#L135) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/PokewalkerScreen.lua:213](../src/ui/PokewalkerScreen.lua#L213) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/ui/ProfileAvatar.lua:11](../src/ui/ProfileAvatar.lua#L11) | newImage | Account avatar decode; outside palette switch |
| [src/ui/SlotMachine.lua:591](../src/ui/SlotMachine.lua#L591) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/SlotMachine.lua:595](../src/ui/SlotMachine.lua#L595) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/SummaryMenu.lua:169](../src/ui/SummaryMenu.lua#L169) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/SummaryMenu.lua:178](../src/ui/SummaryMenu.lua#L178) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/SurfingMinigame.lua:95](../src/ui/SurfingMinigame.lua#L95) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TitleState.lua:118](../src/ui/TitleState.lua#L118) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:88](../src/ui/TownMap.lua#L88) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:179](../src/ui/TownMap.lua#L179) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:190](../src/ui/TownMap.lua#L190) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:296](../src/ui/TownMap.lua#L296) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:469](../src/ui/TownMap.lua#L469) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TownMap.lua:548](../src/ui/TownMap.lua#L548) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TradeAnim.lua:67](../src/ui/TradeAnim.lua#L67) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TradeAnim.lua:94](../src/ui/TradeAnim.lua#L94) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/TrainerCard.lua:47](../src/ui/TrainerCard.lua#L47) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/ui/UnownPuzzle.lua:147](../src/ui/UnownPuzzle.lua#L147) | mapPixel | Cached puzzle-art palette or plain PNG fallback |
| [src/ui/UnownPuzzle.lua:152](../src/ui/UnownPuzzle.lua#L152) | newImage | Cached puzzle-art palette or plain PNG fallback |
| [src/ui/UnownPuzzle.lua:155](../src/ui/UnownPuzzle.lua#L155) | newImage | Cached puzzle-art palette or plain PNG fallback |
| [src/ui/YellowIntro.lua:223](../src/ui/YellowIntro.lua#L223) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/Gen3FieldMove.lua:127](../src/world/Gen3FieldMove.lua#L127) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen3FieldMove.lua:253](../src/world/Gen3FieldMove.lua#L253) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen3MirageTower.lua:144](../src/world/Gen3MirageTower.lua#L144) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen4AreaPopup.lua:143](../src/world/Gen4AreaPopup.lua#L143) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen4HMCutIn.lua:81](../src/world/Gen4HMCutIn.lua#L81) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen5FishingLure.lua:62](../src/world/Gen5FishingLure.lua#L62) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/Gen5Phenomena.lua:241](../src/world/Gen5Phenomena.lua#L241) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/world/OverworldController.lua:16470](../src/world/OverworldController.lua#L16470) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:16473](../src/world/OverworldController.lua#L16473) | mapPixel | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:16480](../src/world/OverworldController.lua#L16480) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17486](../src/world/OverworldController.lua#L17486) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17560](../src/world/OverworldController.lua#L17560) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17681](../src/world/OverworldController.lua#L17681) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17782](../src/world/OverworldController.lua#L17782) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17949](../src/world/OverworldController.lua#L17949) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18033](../src/world/OverworldController.lua#L18033) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18067](../src/world/OverworldController.lua#L18067) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:19391](../src/world/OverworldController.lua#L19391) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/Player.lua:119](../src/world/Player.lua#L119) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [mods/DRAMATIC_SHAPE/lib/BattlePics.lua:395](../mods/DRAMATIC_SHAPE/lib/BattlePics.lua#L395) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Gen3.lua:7128](../mods/DRAMATIC_SHAPE/lib/Gen3.lua#L7128) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Gen3.lua:7157](../mods/DRAMATIC_SHAPE/lib/Gen3.lua#L7157) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/GlassMask.lua:114](../mods/DRAMATIC_SHAPE/lib/GlassMask.lua#L114) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/GlassMask.lua:124](../mods/DRAMATIC_SHAPE/lib/GlassMask.lua#L124) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/GlassMask.lua:156](../mods/DRAMATIC_SHAPE/lib/GlassMask.lua#L156) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/HordeGun.lua:119](../mods/DRAMATIC_SHAPE/lib/HordeGun.lua#L119) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/HordeGun.lua:126](../mods/DRAMATIC_SHAPE/lib/HordeGun.lua#L126) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Pokedex.lua:78](../mods/DRAMATIC_SHAPE/lib/Pokedex.lua#L78) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Pokedex.lua:85](../mods/DRAMATIC_SHAPE/lib/Pokedex.lua#L85) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua:30](../mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua#L30) | mapPixel | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua:34](../mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua#L34) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua:38](../mods/DRAMATIC_SHAPE/lib/PolishedFruitSprite.lua#L38) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/ShadowMap.lua:243](../mods/DRAMATIC_SHAPE/lib/ShadowMap.lua#L243) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Sky.lua:319](../mods/DRAMATIC_SHAPE/lib/Sky.lua#L319) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/Sky.lua:328](../mods/DRAMATIC_SHAPE/lib/Sky.lua#L328) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua:178](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L178) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua:609](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L609) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua:764](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L764) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
| [mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua:876](../mods/DRAMATIC_SHAPE/lib/TerrainAtlas.lua#L876) | newImage | Voxel RGBA texture/readback/animation; compatibility consumer |
<!-- palette-inventory:end -->
