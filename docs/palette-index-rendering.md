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

**T0 is implemented; the required acceptance gate is not green.** Keep its PR
in draft and stop before T1. Repairing this Gen 3 compatibility/fixture mismatch
inside the palette migration would cross X5. Resolve it separately or obtain
an explicit scope decision before continuing. The RG8 decision is recorded
above, but no index-rendering implementation/default change is included here.
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

<!-- palette-inventory:start -->
### Reproducible source references

Generated with `python3 tools/palette-index-render/inventory.py`. This lists lexical references (including re-exports), not an inferred dynamic call graph. Indirect image consumers are described explicitly above. Generation-specific files remain listed to make the X5 exclusions reviewable.

| Consumer / definition | Surface | Lines |
| --- | --- | --- |
| `src/battle/AnimPlayer.lua` | PaletteFX | [709](../src/battle/AnimPlayer.lua#L709) |
| `src/battle/BattleState.lua` | PaletteFX | [655](../src/battle/BattleState.lua#L655), [771](../src/battle/BattleState.lua#L771), [772](../src/battle/BattleState.lua#L772), [774](../src/battle/BattleState.lua#L774), [776](../src/battle/BattleState.lua#L776), [782](../src/battle/BattleState.lua#L782), [783](../src/battle/BattleState.lua#L783), [786](../src/battle/BattleState.lua#L786), [804](../src/battle/BattleState.lua#L804), [805](../src/battle/BattleState.lua#L805), [838](../src/battle/BattleState.lua#L838), [839](../src/battle/BattleState.lua#L839), [843](../src/battle/BattleState.lua#L843), [867](../src/battle/BattleState.lua#L867), [868](../src/battle/BattleState.lua#L868), [872](../src/battle/BattleState.lua#L872), [875](../src/battle/BattleState.lua#L875), [890](../src/battle/BattleState.lua#L890), [896](../src/battle/BattleState.lua#L896), [912](../src/battle/BattleState.lua#L912), [913](../src/battle/BattleState.lua#L913), [1107](../src/battle/BattleState.lua#L1107), [1108](../src/battle/BattleState.lua#L1108), [1110](../src/battle/BattleState.lua#L1110), [3799](../src/battle/BattleState.lua#L3799), [11424](../src/battle/BattleState.lua#L11424), [11425](../src/battle/BattleState.lua#L11425), [11428](../src/battle/BattleState.lua#L11428), [11515](../src/battle/BattleState.lua#L11515), [11516](../src/battle/BattleState.lua#L11516), [11522](../src/battle/BattleState.lua#L11522), [11523](../src/battle/BattleState.lua#L11523), [12337](../src/battle/BattleState.lua#L12337), [12339](../src/battle/BattleState.lua#L12339), [12340](../src/battle/BattleState.lua#L12340), [12362](../src/battle/BattleState.lua#L12362), [12363](../src/battle/BattleState.lua#L12363), [12379](../src/battle/BattleState.lua#L12379), [12383](../src/battle/BattleState.lua#L12383), [12398](../src/battle/BattleState.lua#L12398), [12401](../src/battle/BattleState.lua#L12401), [12414](../src/battle/BattleState.lua#L12414), [12415](../src/battle/BattleState.lua#L12415), [12472](../src/battle/BattleState.lua#L12472), [12473](../src/battle/BattleState.lua#L12473), [12497](../src/battle/BattleState.lua#L12497), [12498](../src/battle/BattleState.lua#L12498) |
| `src/battle/Gen2AnimPlayer.lua` | PaletteFX | [932](../src/battle/Gen2AnimPlayer.lua#L932) |
| `src/battle/Gen3Battle.lua` | PaletteFX | [44](../src/battle/Gen3Battle.lua#L44), [644](../src/battle/Gen3Battle.lua#L644), [2593](../src/battle/Gen3Battle.lua#L2593), [3272](../src/battle/Gen3Battle.lua#L3272) |
| `src/battle/WideBattle.lua` | PaletteFX | [17](../src/battle/WideBattle.lua#L17), [38](../src/battle/WideBattle.lua#L38), [476](../src/battle/WideBattle.lua#L476), [546](../src/battle/WideBattle.lua#L546) |
| `src/compat/gen1/AtlasRuntime.lua` | TileRenderer | [178](../src/compat/gen1/AtlasRuntime.lua#L178) |
| `src/core/CheckpointWorld.lua` | PaletteFX | [4](../src/core/CheckpointWorld.lua#L4) |
| `src/core/Game.lua` | TileRenderer | [2193](../src/core/Game.lua#L2193) |
| `src/core/Game.lua` | PaletteFX | [1609](../src/core/Game.lua#L1609), [1610](../src/core/Game.lua#L1610), [2185](../src/core/Game.lua#L2185) |
| `src/core/GameVersion.lua` | PaletteFX | [1116](../src/core/GameVersion.lua#L1116) |
| `src/core/ModCompat.lua` | PaletteFX | [65](../src/core/ModCompat.lua#L65) |
| `src/core/game3/field_view.lua` | TileRenderer | [190](../src/core/game3/field_view.lua#L190) |
| `src/import/BorrowedTiles.lua` | TileRenderer | [356](../src/import/BorrowedTiles.lua#L356) |
| `src/import/pmd/Sprite.lua` | SpriteRenderer | [43](../src/import/pmd/Sprite.lua#L43), [65](../src/import/pmd/Sprite.lua#L65) |
| `src/mods/ActorRenderData.lua` | SpriteRenderer | [88](../src/mods/ActorRenderData.lua#L88) |
| `src/mods/Loader.lua` | PaletteFX | [1611](../src/mods/Loader.lua#L1611), [2034](../src/mods/Loader.lua#L2034) |
| `src/mods/ManagerState.lua` | PaletteFX | [31](../src/mods/ManagerState.lua#L31) |
| `src/mods/RenderData.lua` | TileRenderer | [500](../src/mods/RenderData.lua#L500), [516](../src/mods/RenderData.lua#L516) |
| `src/render/GbcColorCorrection.lua` | PaletteFX | [6](../src/render/GbcColorCorrection.lua#L6), [118](../src/render/GbcColorCorrection.lua#L118) |
| `src/render/Gen2PaletteDraw.lua` | PaletteFX | [4](../src/render/Gen2PaletteDraw.lua#L4) |
| `src/render/Gen2Presentation.lua` | PaletteFX | [5](../src/render/Gen2Presentation.lua#L5) |
| `src/render/HudTiles.lua` | PaletteFX | [285](../src/render/HudTiles.lua#L285), [293](../src/render/HudTiles.lua#L293), [342](../src/render/HudTiles.lua#L342), [343](../src/render/HudTiles.lua#L343) |
| `src/render/PaletteFX.lua` | SpriteRenderer | [1221](../src/render/PaletteFX.lua#L1221) |
| `src/render/PaletteFX.lua` | TileRenderer | [1222](../src/render/PaletteFX.lua#L1222) |
| `src/render/PaletteFX.lua` | PaletteFX | [28](../src/render/PaletteFX.lua#L28), [37](../src/render/PaletteFX.lua#L37), [45](../src/render/PaletteFX.lua#L45), [49](../src/render/PaletteFX.lua#L49), [51](../src/render/PaletteFX.lua#L51), [53](../src/render/PaletteFX.lua#L53), [54](../src/render/PaletteFX.lua#L54), [55](../src/render/PaletteFX.lua#L55), [56](../src/render/PaletteFX.lua#L56), [84](../src/render/PaletteFX.lua#L84), [91](../src/render/PaletteFX.lua#L91), [94](../src/render/PaletteFX.lua#L94), [101](../src/render/PaletteFX.lua#L101), [103](../src/render/PaletteFX.lua#L103), [111](../src/render/PaletteFX.lua#L111), [117](../src/render/PaletteFX.lua#L117), [128](../src/render/PaletteFX.lua#L128), [131](../src/render/PaletteFX.lua#L131), [146](../src/render/PaletteFX.lua#L146), [151](../src/render/PaletteFX.lua#L151), [162](../src/render/PaletteFX.lua#L162), [163](../src/render/PaletteFX.lua#L163), [165](../src/render/PaletteFX.lua#L165), [169](../src/render/PaletteFX.lua#L169), [179](../src/render/PaletteFX.lua#L179), [181](../src/render/PaletteFX.lua#L181), [183](../src/render/PaletteFX.lua#L183), [197](../src/render/PaletteFX.lua#L197), [201](../src/render/PaletteFX.lua#L201), [202](../src/render/PaletteFX.lua#L202), [207](../src/render/PaletteFX.lua#L207), [233](../src/render/PaletteFX.lua#L233), [252](../src/render/PaletteFX.lua#L252), [259](../src/render/PaletteFX.lua#L259), [260](../src/render/PaletteFX.lua#L260), [281](../src/render/PaletteFX.lua#L281), [293](../src/render/PaletteFX.lua#L293), [302](../src/render/PaletteFX.lua#L302), [306](../src/render/PaletteFX.lua#L306), [337](../src/render/PaletteFX.lua#L337), [339](../src/render/PaletteFX.lua#L339), [340](../src/render/PaletteFX.lua#L340), [341](../src/render/PaletteFX.lua#L341), [372](../src/render/PaletteFX.lua#L372), [379](../src/render/PaletteFX.lua#L379), [384](../src/render/PaletteFX.lua#L384), [394](../src/render/PaletteFX.lua#L394), [402](../src/render/PaletteFX.lua#L402), [403](../src/render/PaletteFX.lua#L403), [420](../src/render/PaletteFX.lua#L420), [421](../src/render/PaletteFX.lua#L421), [427](../src/render/PaletteFX.lua#L427), [428](../src/render/PaletteFX.lua#L428), [472](../src/render/PaletteFX.lua#L472), [476](../src/render/PaletteFX.lua#L476), [485](../src/render/PaletteFX.lua#L485), [486](../src/render/PaletteFX.lua#L486), [505](../src/render/PaletteFX.lua#L505), [506](../src/render/PaletteFX.lua#L506), [507](../src/render/PaletteFX.lua#L507), [522](../src/render/PaletteFX.lua#L522), [523](../src/render/PaletteFX.lua#L523), [545](../src/render/PaletteFX.lua#L545), [546](../src/render/PaletteFX.lua#L546), [549](../src/render/PaletteFX.lua#L549), [550](../src/render/PaletteFX.lua#L550), [556](../src/render/PaletteFX.lua#L556), [559](../src/render/PaletteFX.lua#L559), [560](../src/render/PaletteFX.lua#L560), [562](../src/render/PaletteFX.lua#L562), [576](../src/render/PaletteFX.lua#L576), [583](../src/render/PaletteFX.lua#L583), [595](../src/render/PaletteFX.lua#L595), [597](../src/render/PaletteFX.lua#L597), [619](../src/render/PaletteFX.lua#L619), [643](../src/render/PaletteFX.lua#L643), [647](../src/render/PaletteFX.lua#L647), [662](../src/render/PaletteFX.lua#L662), [680](../src/render/PaletteFX.lua#L680), [682](../src/render/PaletteFX.lua#L682), [693](../src/render/PaletteFX.lua#L693), [708](../src/render/PaletteFX.lua#L708), [709](../src/render/PaletteFX.lua#L709), [728](../src/render/PaletteFX.lua#L728), [732](../src/render/PaletteFX.lua#L732), [743](../src/render/PaletteFX.lua#L743), [747](../src/render/PaletteFX.lua#L747), [780](../src/render/PaletteFX.lua#L780), [781](../src/render/PaletteFX.lua#L781), [782](../src/render/PaletteFX.lua#L782), [809](../src/render/PaletteFX.lua#L809), [834](../src/render/PaletteFX.lua#L834), [835](../src/render/PaletteFX.lua#L835), [837](../src/render/PaletteFX.lua#L837), [845](../src/render/PaletteFX.lua#L845), [849](../src/render/PaletteFX.lua#L849), [853](../src/render/PaletteFX.lua#L853), [857](../src/render/PaletteFX.lua#L857), [874](../src/render/PaletteFX.lua#L874), [880](../src/render/PaletteFX.lua#L880), [882](../src/render/PaletteFX.lua#L882), [884](../src/render/PaletteFX.lua#L884), [887](../src/render/PaletteFX.lua#L887), [888](../src/render/PaletteFX.lua#L888), [909](../src/render/PaletteFX.lua#L909), [910](../src/render/PaletteFX.lua#L910), [918](../src/render/PaletteFX.lua#L918), [919](../src/render/PaletteFX.lua#L919), [924](../src/render/PaletteFX.lua#L924), [929](../src/render/PaletteFX.lua#L929), [940](../src/render/PaletteFX.lua#L940), [945](../src/render/PaletteFX.lua#L945), [949](../src/render/PaletteFX.lua#L949), [1016](../src/render/PaletteFX.lua#L1016), [1026](../src/render/PaletteFX.lua#L1026), [1027](../src/render/PaletteFX.lua#L1027), [1034](../src/render/PaletteFX.lua#L1034), [1035](../src/render/PaletteFX.lua#L1035), [1050](../src/render/PaletteFX.lua#L1050), [1051](../src/render/PaletteFX.lua#L1051), [1086](../src/render/PaletteFX.lua#L1086), [1087](../src/render/PaletteFX.lua#L1087), [1107](../src/render/PaletteFX.lua#L1107), [1114](../src/render/PaletteFX.lua#L1114), [1123](../src/render/PaletteFX.lua#L1123), [1124](../src/render/PaletteFX.lua#L1124), [1125](../src/render/PaletteFX.lua#L1125), [1131](../src/render/PaletteFX.lua#L1131), [1148](../src/render/PaletteFX.lua#L1148), [1171](../src/render/PaletteFX.lua#L1171), [1175](../src/render/PaletteFX.lua#L1175), [1179](../src/render/PaletteFX.lua#L1179), [1187](../src/render/PaletteFX.lua#L1187), [1188](../src/render/PaletteFX.lua#L1188), [1189](../src/render/PaletteFX.lua#L1189), [1194](../src/render/PaletteFX.lua#L1194), [1198](../src/render/PaletteFX.lua#L1198), [1200](../src/render/PaletteFX.lua#L1200), [1201](../src/render/PaletteFX.lua#L1201), [1202](../src/render/PaletteFX.lua#L1202), [1203](../src/render/PaletteFX.lua#L1203), [1205](../src/render/PaletteFX.lua#L1205), [1206](../src/render/PaletteFX.lua#L1206), [1210](../src/render/PaletteFX.lua#L1210), [1211](../src/render/PaletteFX.lua#L1211), [1212](../src/render/PaletteFX.lua#L1212), [1238](../src/render/PaletteFX.lua#L1238), [1245](../src/render/PaletteFX.lua#L1245), [1249](../src/render/PaletteFX.lua#L1249), [1250](../src/render/PaletteFX.lua#L1250), [1254](../src/render/PaletteFX.lua#L1254), [1255](../src/render/PaletteFX.lua#L1255), [1257](../src/render/PaletteFX.lua#L1257), [1258](../src/render/PaletteFX.lua#L1258), [1262](../src/render/PaletteFX.lua#L1262), [1263](../src/render/PaletteFX.lua#L1263), [1265](../src/render/PaletteFX.lua#L1265), [1273](../src/render/PaletteFX.lua#L1273), [1274](../src/render/PaletteFX.lua#L1274), [1277](../src/render/PaletteFX.lua#L1277), [1280](../src/render/PaletteFX.lua#L1280), [1282](../src/render/PaletteFX.lua#L1282), [1284](../src/render/PaletteFX.lua#L1284), [1291](../src/render/PaletteFX.lua#L1291), [1292](../src/render/PaletteFX.lua#L1292), [1295](../src/render/PaletteFX.lua#L1295), [1296](../src/render/PaletteFX.lua#L1296), [1304](../src/render/PaletteFX.lua#L1304), [1310](../src/render/PaletteFX.lua#L1310), [1312](../src/render/PaletteFX.lua#L1312), [1315](../src/render/PaletteFX.lua#L1315), [1332](../src/render/PaletteFX.lua#L1332), [1333](../src/render/PaletteFX.lua#L1333), [1334](../src/render/PaletteFX.lua#L1334), [1342](../src/render/PaletteFX.lua#L1342), [1344](../src/render/PaletteFX.lua#L1344), [1351](../src/render/PaletteFX.lua#L1351), [1353](../src/render/PaletteFX.lua#L1353), [1355](../src/render/PaletteFX.lua#L1355), [1357](../src/render/PaletteFX.lua#L1357), [1364](../src/render/PaletteFX.lua#L1364), [1365](../src/render/PaletteFX.lua#L1365), [1366](../src/render/PaletteFX.lua#L1366), [1368](../src/render/PaletteFX.lua#L1368), [1372](../src/render/PaletteFX.lua#L1372), [1373](../src/render/PaletteFX.lua#L1373), [1384](../src/render/PaletteFX.lua#L1384), [1389](../src/render/PaletteFX.lua#L1389), [1390](../src/render/PaletteFX.lua#L1390), [1396](../src/render/PaletteFX.lua#L1396), [1397](../src/render/PaletteFX.lua#L1397), [1398](../src/render/PaletteFX.lua#L1398), [1401](../src/render/PaletteFX.lua#L1401), [1404](../src/render/PaletteFX.lua#L1404), [1405](../src/render/PaletteFX.lua#L1405), [1442](../src/render/PaletteFX.lua#L1442), [1446](../src/render/PaletteFX.lua#L1446), [1453](../src/render/PaletteFX.lua#L1453), [1457](../src/render/PaletteFX.lua#L1457), [1459](../src/render/PaletteFX.lua#L1459), [1460](../src/render/PaletteFX.lua#L1460), [1467](../src/render/PaletteFX.lua#L1467), [1470](../src/render/PaletteFX.lua#L1470), [1474](../src/render/PaletteFX.lua#L1474) |
| `src/render/PlayerPalette.lua` | SpriteRenderer | [56](../src/render/PlayerPalette.lua#L56) |
| `src/render/Renderer.lua` | PaletteFX | [12](../src/render/Renderer.lua#L12), [382](../src/render/Renderer.lua#L382), [383](../src/render/Renderer.lua#L383), [386](../src/render/Renderer.lua#L386), [387](../src/render/Renderer.lua#L387), [510](../src/render/Renderer.lua#L510), [516](../src/render/Renderer.lua#L516), [538](../src/render/Renderer.lua#L538), [551](../src/render/Renderer.lua#L551), [635](../src/render/Renderer.lua#L635), [646](../src/render/Renderer.lua#L646), [706](../src/render/Renderer.lua#L706), [707](../src/render/Renderer.lua#L707), [709](../src/render/Renderer.lua#L709), [796](../src/render/Renderer.lua#L796), [805](../src/render/Renderer.lua#L805), [806](../src/render/Renderer.lua#L806), [821](../src/render/Renderer.lua#L821), [822](../src/render/Renderer.lua#L822), [835](../src/render/Renderer.lua#L835), [1034](../src/render/Renderer.lua#L1034), [1035](../src/render/Renderer.lua#L1035), [1086](../src/render/Renderer.lua#L1086), [1175](../src/render/Renderer.lua#L1175), [1325](../src/render/Renderer.lua#L1325), [1332](../src/render/Renderer.lua#L1332), [1338](../src/render/Renderer.lua#L1338), [1658](../src/render/Renderer.lua#L1658) |
| `src/render/SpriteRenderer.lua` | SpriteRenderer | [12](../src/render/SpriteRenderer.lua#L12), [13](../src/render/SpriteRenderer.lua#L13), [91](../src/render/SpriteRenderer.lua#L91), [99](../src/render/SpriteRenderer.lua#L99), [104](../src/render/SpriteRenderer.lua#L104), [120](../src/render/SpriteRenderer.lua#L120), [121](../src/render/SpriteRenderer.lua#L121), [122](../src/render/SpriteRenderer.lua#L122), [129](../src/render/SpriteRenderer.lua#L129), [130](../src/render/SpriteRenderer.lua#L130), [207](../src/render/SpriteRenderer.lua#L207), [216](../src/render/SpriteRenderer.lua#L216), [234](../src/render/SpriteRenderer.lua#L234), [275](../src/render/SpriteRenderer.lua#L275), [317](../src/render/SpriteRenderer.lua#L317), [325](../src/render/SpriteRenderer.lua#L325), [408](../src/render/SpriteRenderer.lua#L408), [412](../src/render/SpriteRenderer.lua#L412), [479](../src/render/SpriteRenderer.lua#L479), [491](../src/render/SpriteRenderer.lua#L491), [495](../src/render/SpriteRenderer.lua#L495), [522](../src/render/SpriteRenderer.lua#L522), [584](../src/render/SpriteRenderer.lua#L584), [617](../src/render/SpriteRenderer.lua#L617), [660](../src/render/SpriteRenderer.lua#L660), [672](../src/render/SpriteRenderer.lua#L672), [691](../src/render/SpriteRenderer.lua#L691) |
| `src/render/SpriteRenderer.lua` | TileRenderer | [661](../src/render/SpriteRenderer.lua#L661), [662](../src/render/SpriteRenderer.lua#L662), [663](../src/render/SpriteRenderer.lua#L663) |
| `src/render/SpriteRenderer.lua` | PaletteFX | [7](../src/render/SpriteRenderer.lua#L7), [53](../src/render/SpriteRenderer.lua#L53), [54](../src/render/SpriteRenderer.lua#L54), [242](../src/render/SpriteRenderer.lua#L242), [245](../src/render/SpriteRenderer.lua#L245), [246](../src/render/SpriteRenderer.lua#L246), [248](../src/render/SpriteRenderer.lua#L248), [249](../src/render/SpriteRenderer.lua#L249), [250](../src/render/SpriteRenderer.lua#L250), [252](../src/render/SpriteRenderer.lua#L252), [261](../src/render/SpriteRenderer.lua#L261), [264](../src/render/SpriteRenderer.lua#L264), [283](../src/render/SpriteRenderer.lua#L283), [284](../src/render/SpriteRenderer.lua#L284), [287](../src/render/SpriteRenderer.lua#L287), [288](../src/render/SpriteRenderer.lua#L288), [289](../src/render/SpriteRenderer.lua#L289), [293](../src/render/SpriteRenderer.lua#L293), [295](../src/render/SpriteRenderer.lua#L295), [296](../src/render/SpriteRenderer.lua#L296), [299](../src/render/SpriteRenderer.lua#L299), [332](../src/render/SpriteRenderer.lua#L332), [333](../src/render/SpriteRenderer.lua#L333), [340](../src/render/SpriteRenderer.lua#L340), [341](../src/render/SpriteRenderer.lua#L341), [347](../src/render/SpriteRenderer.lua#L347), [351](../src/render/SpriteRenderer.lua#L351), [353](../src/render/SpriteRenderer.lua#L353), [360](../src/render/SpriteRenderer.lua#L360), [363](../src/render/SpriteRenderer.lua#L363), [418](../src/render/SpriteRenderer.lua#L418), [613](../src/render/SpriteRenderer.lua#L613), [675](../src/render/SpriteRenderer.lua#L675), [676](../src/render/SpriteRenderer.lua#L676), [677](../src/render/SpriteRenderer.lua#L677), [679](../src/render/SpriteRenderer.lua#L679), [680](../src/render/SpriteRenderer.lua#L680), [682](../src/render/SpriteRenderer.lua#L682) |
| `src/render/StadiumArt.lua` | PaletteFX | [158](../src/render/StadiumArt.lua#L158) |
| `src/render/TileRenderer.lua` | TileRenderer | [20](../src/render/TileRenderer.lua#L20), [21](../src/render/TileRenderer.lua#L21), [32](../src/render/TileRenderer.lua#L32), [33](../src/render/TileRenderer.lua#L33), [37](../src/render/TileRenderer.lua#L37), [44](../src/render/TileRenderer.lua#L44), [46](../src/render/TileRenderer.lua#L46), [48](../src/render/TileRenderer.lua#L48), [51](../src/render/TileRenderer.lua#L51), [54](../src/render/TileRenderer.lua#L54), [55](../src/render/TileRenderer.lua#L55), [57](../src/render/TileRenderer.lua#L57), [60](../src/render/TileRenderer.lua#L60), [61](../src/render/TileRenderer.lua#L61), [62](../src/render/TileRenderer.lua#L62), [68](../src/render/TileRenderer.lua#L68), [70](../src/render/TileRenderer.lua#L70), [74](../src/render/TileRenderer.lua#L74), [75](../src/render/TileRenderer.lua#L75), [78](../src/render/TileRenderer.lua#L78), [79](../src/render/TileRenderer.lua#L79), [102](../src/render/TileRenderer.lua#L102), [140](../src/render/TileRenderer.lua#L140), [162](../src/render/TileRenderer.lua#L162), [178](../src/render/TileRenderer.lua#L178), [192](../src/render/TileRenderer.lua#L192), [203](../src/render/TileRenderer.lua#L203), [230](../src/render/TileRenderer.lua#L230), [413](../src/render/TileRenderer.lua#L413), [414](../src/render/TileRenderer.lua#L414), [417](../src/render/TileRenderer.lua#L417), [418](../src/render/TileRenderer.lua#L418), [422](../src/render/TileRenderer.lua#L422), [431](../src/render/TileRenderer.lua#L431), [455](../src/render/TileRenderer.lua#L455), [463](../src/render/TileRenderer.lua#L463), [580](../src/render/TileRenderer.lua#L580), [658](../src/render/TileRenderer.lua#L658), [693](../src/render/TileRenderer.lua#L693), [731](../src/render/TileRenderer.lua#L731), [777](../src/render/TileRenderer.lua#L777), [790](../src/render/TileRenderer.lua#L790), [847](../src/render/TileRenderer.lua#L847), [855](../src/render/TileRenderer.lua#L855), [922](../src/render/TileRenderer.lua#L922), [991](../src/render/TileRenderer.lua#L991), [994](../src/render/TileRenderer.lua#L994), [1003](../src/render/TileRenderer.lua#L1003), [1012](../src/render/TileRenderer.lua#L1012), [1040](../src/render/TileRenderer.lua#L1040), [1217](../src/render/TileRenderer.lua#L1217), [1453](../src/render/TileRenderer.lua#L1453), [1472](../src/render/TileRenderer.lua#L1472), [1487](../src/render/TileRenderer.lua#L1487), [1500](../src/render/TileRenderer.lua#L1500), [1504](../src/render/TileRenderer.lua#L1504), [1505](../src/render/TileRenderer.lua#L1505), [1544](../src/render/TileRenderer.lua#L1544), [1605](../src/render/TileRenderer.lua#L1605), [1619](../src/render/TileRenderer.lua#L1619), [1667](../src/render/TileRenderer.lua#L1667), [1672](../src/render/TileRenderer.lua#L1672), [1681](../src/render/TileRenderer.lua#L1681), [1815](../src/render/TileRenderer.lua#L1815), [1824](../src/render/TileRenderer.lua#L1824), [1860](../src/render/TileRenderer.lua#L1860), [1944](../src/render/TileRenderer.lua#L1944), [1963](../src/render/TileRenderer.lua#L1963), [1976](../src/render/TileRenderer.lua#L1976), [1992](../src/render/TileRenderer.lua#L1992), [2000](../src/render/TileRenderer.lua#L2000), [2017](../src/render/TileRenderer.lua#L2017), [2026](../src/render/TileRenderer.lua#L2026), [2089](../src/render/TileRenderer.lua#L2089), [2213](../src/render/TileRenderer.lua#L2213), [2266](../src/render/TileRenderer.lua#L2266), [2296](../src/render/TileRenderer.lua#L2296), [2308](../src/render/TileRenderer.lua#L2308), [2348](../src/render/TileRenderer.lua#L2348), [2356](../src/render/TileRenderer.lua#L2356), [2371](../src/render/TileRenderer.lua#L2371), [2396](../src/render/TileRenderer.lua#L2396), [2407](../src/render/TileRenderer.lua#L2407), [2414](../src/render/TileRenderer.lua#L2414), [2456](../src/render/TileRenderer.lua#L2456), [2484](../src/render/TileRenderer.lua#L2484), [2507](../src/render/TileRenderer.lua#L2507), [2515](../src/render/TileRenderer.lua#L2515), [2553](../src/render/TileRenderer.lua#L2553), [2557](../src/render/TileRenderer.lua#L2557), [2564](../src/render/TileRenderer.lua#L2564) |
| `src/render/TileRenderer.lua` | PaletteFX | [15](../src/render/TileRenderer.lua#L15), [507](../src/render/TileRenderer.lua#L507), [597](../src/render/TileRenderer.lua#L597), [604](../src/render/TileRenderer.lua#L604), [612](../src/render/TileRenderer.lua#L612), [613](../src/render/TileRenderer.lua#L613), [637](../src/render/TileRenderer.lua#L637), [649](../src/render/TileRenderer.lua#L649), [780](../src/render/TileRenderer.lua#L780), [782](../src/render/TileRenderer.lua#L782), [797](../src/render/TileRenderer.lua#L797), [805](../src/render/TileRenderer.lua#L805), [859](../src/render/TileRenderer.lua#L859), [880](../src/render/TileRenderer.lua#L880), [924](../src/render/TileRenderer.lua#L924), [1546](../src/render/TileRenderer.lua#L1546), [1555](../src/render/TileRenderer.lua#L1555), [1579](../src/render/TileRenderer.lua#L1579), [1580](../src/render/TileRenderer.lua#L1580), [1696](../src/render/TileRenderer.lua#L1696), [1795](../src/render/TileRenderer.lua#L1795), [1796](../src/render/TileRenderer.lua#L1796), [1868](../src/render/TileRenderer.lua#L1868), [1905](../src/render/TileRenderer.lua#L1905), [1921](../src/render/TileRenderer.lua#L1921), [1982](../src/render/TileRenderer.lua#L1982), [2350](../src/render/TileRenderer.lua#L2350) |
| `src/script/Gen2Commands.lua` | PaletteFX | [1928](../src/script/Gen2Commands.lua#L1928), [1929](../src/script/Gen2Commands.lua#L1929), [1930](../src/script/Gen2Commands.lua#L1930), [1932](../src/script/Gen2Commands.lua#L1932) |
| `src/translation/rompack/asian_layout.lua` | PaletteFX | [203](../src/translation/rompack/asian_layout.lua#L203), [253](../src/translation/rompack/asian_layout.lua#L253), [276](../src/translation/rompack/asian_layout.lua#L276) |
| `src/translation/rompack/main.lua` | TileRenderer | [96](../src/translation/rompack/main.lua#L96) |
| `src/ui/BagMenu.lua` | PaletteFX | [1125](../src/ui/BagMenu.lua#L1125) |
| `src/ui/BirchSpeech.lua` | PaletteFX | [76](../src/ui/BirchSpeech.lua#L76) |
| `src/ui/DexEntryMenu.lua` | PaletteFX | [22](../src/ui/DexEntryMenu.lua#L22), [162](../src/ui/DexEntryMenu.lua#L162), [229](../src/ui/DexEntryMenu.lua#L229) |
| `src/ui/EvolutionState.lua` | PaletteFX | [22](../src/ui/EvolutionState.lua#L22), [153](../src/ui/EvolutionState.lua#L153) |
| `src/ui/Gen2BoxMenu.lua` | PaletteFX | [53](../src/ui/Gen2BoxMenu.lua#L53) |
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
| `src/ui/TitleState.lua` | PaletteFX | [59](../src/ui/TitleState.lua#L59), [135](../src/ui/TitleState.lua#L135) |
| `src/ui/TownMap.lua` | PaletteFX | [34](../src/ui/TownMap.lua#L34), [460](../src/ui/TownMap.lua#L460) |
| `src/ui/TradeAnim.lua` | PaletteFX | [102](../src/ui/TradeAnim.lua#L102), [722](../src/ui/TradeAnim.lua#L722), [966](../src/ui/TradeAnim.lua#L966) |
| `src/ui/TradeAnimKit.lua` | PaletteFX | [98](../src/ui/TradeAnimKit.lua#L98), [115](../src/ui/TradeAnimKit.lua#L115) |
| `src/ui/TrainerCard.lua` | PaletteFX | [31](../src/ui/TrainerCard.lua#L31), [232](../src/ui/TrainerCard.lua#L232), [278](../src/ui/TrainerCard.lua#L278), [293](../src/ui/TrainerCard.lua#L293) |
| `src/ui/UnownPuzzle.lua` | PaletteFX | [22](../src/ui/UnownPuzzle.lua#L22), [205](../src/ui/UnownPuzzle.lua#L205) |
| `src/ui/YellowIntro.lua` | PaletteFX | [287](../src/ui/YellowIntro.lua#L287) |
| `src/world/Gen3FieldMove.lua` | PaletteFX | [399](../src/world/Gen3FieldMove.lua#L399) |
| `src/world/Gen4BerryPatches.lua` | SpriteRenderer | [123](../src/world/Gen4BerryPatches.lua#L123), [136](../src/world/Gen4BerryPatches.lua#L136) |
| `src/world/Gen4FishingTask.lua` | SpriteRenderer | [160](../src/world/Gen4FishingTask.lua#L160), [164](../src/world/Gen4FishingTask.lua#L164) |
| `src/world/Gen4HMCutIn.lua` | PaletteFX | [327](../src/world/Gen4HMCutIn.lua#L327) |
| `src/world/HgssFollowMon.lua` | SpriteRenderer | [214](../src/world/HgssFollowMon.lua#L214), [215](../src/world/HgssFollowMon.lua#L215) |
| `src/world/MapLoader.lua` | TileRenderer | [16](../src/world/MapLoader.lua#L16), [153](../src/world/MapLoader.lua#L153), [156](../src/world/MapLoader.lua#L156) |
| `src/world/NPC-1.lua` | SpriteRenderer | [7](../src/world/NPC-1.lua#L7), [473](../src/world/NPC-1.lua#L473), [709](../src/world/NPC-1.lua#L709) |
| `src/world/NPC.lua` | SpriteRenderer | [7](../src/world/NPC.lua#L7), [478](../src/world/NPC.lua#L478), [720](../src/world/NPC.lua#L720) |
| `src/world/OverworldController.lua` | SpriteRenderer | [50](../src/world/OverworldController.lua#L50), [61](../src/world/OverworldController.lua#L61), [62](../src/world/OverworldController.lua#L62), [17583](../src/world/OverworldController.lua#L17583), [17725](../src/world/OverworldController.lua#L17725), [18369](../src/world/OverworldController.lua#L18369) |
| `src/world/OverworldController.lua` | TileRenderer | [50](../src/world/OverworldController.lua#L50), [52](../src/world/OverworldController.lua#L52), [53](../src/world/OverworldController.lua#L53), [17035](../src/world/OverworldController.lua#L17035), [17036](../src/world/OverworldController.lua#L17036) |
| `src/world/OverworldController.lua` | PaletteFX | [28](../src/world/OverworldController.lua#L28), [249](../src/world/OverworldController.lua#L249), [1429](../src/world/OverworldController.lua#L1429), [1431](../src/world/OverworldController.lua#L1431), [1440](../src/world/OverworldController.lua#L1440), [1441](../src/world/OverworldController.lua#L1441), [1442](../src/world/OverworldController.lua#L1442), [2657](../src/world/OverworldController.lua#L2657), [2659](../src/world/OverworldController.lua#L2659), [2661](../src/world/OverworldController.lua#L2661), [2662](../src/world/OverworldController.lua#L2662), [2748](../src/world/OverworldController.lua#L2748), [2751](../src/world/OverworldController.lua#L2751), [2753](../src/world/OverworldController.lua#L2753), [2754](../src/world/OverworldController.lua#L2754), [2756](../src/world/OverworldController.lua#L2756), [2763](../src/world/OverworldController.lua#L2763), [2767](../src/world/OverworldController.lua#L2767), [2790](../src/world/OverworldController.lua#L2790), [2791](../src/world/OverworldController.lua#L2791), [2809](../src/world/OverworldController.lua#L2809), [2813](../src/world/OverworldController.lua#L2813), [2819](../src/world/OverworldController.lua#L2819), [2846](../src/world/OverworldController.lua#L2846), [2847](../src/world/OverworldController.lua#L2847), [16901](../src/world/OverworldController.lua#L16901), [16902](../src/world/OverworldController.lua#L16902), [16904](../src/world/OverworldController.lua#L16904), [17891](../src/world/OverworldController.lua#L17891), [17897](../src/world/OverworldController.lua#L17897), [17898](../src/world/OverworldController.lua#L17898), [17900](../src/world/OverworldController.lua#L17900), [17901](../src/world/OverworldController.lua#L17901), [18363](../src/world/OverworldController.lua#L18363), [18442](../src/world/OverworldController.lua#L18442), [18674](../src/world/OverworldController.lua#L18674), [18822](../src/world/OverworldController.lua#L18822), [18825](../src/world/OverworldController.lua#L18825), [18826](../src/world/OverworldController.lua#L18826), [18847](../src/world/OverworldController.lua#L18847), [18849](../src/world/OverworldController.lua#L18849), [18975](../src/world/OverworldController.lua#L18975), [18976](../src/world/OverworldController.lua#L18976), [19534](../src/world/OverworldController.lua#L19534) |
| `src/world/Player.lua` | SpriteRenderer | [9](../src/world/Player.lua#L9), [106](../src/world/Player.lua#L106), [111](../src/world/Player.lua#L111), [309](../src/world/Player.lua#L309), [310](../src/world/Player.lua#L310), [378](../src/world/Player.lua#L378), [386](../src/world/Player.lua#L386), [396](../src/world/Player.lua#L396), [404](../src/world/Player.lua#L404) |
| `src/world/RemotePlayers.lua` | SpriteRenderer | [85](../src/world/RemotePlayers.lua#L85) |
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
| `mods/DRAMATIC_SHAPE/main.lua` | TileRenderer | [397](../mods/DRAMATIC_SHAPE/main.lua#L397), [398](../mods/DRAMATIC_SHAPE/main.lua#L398) |

### Image construction and pixel callbacks

All `mapPixel` and qualified `newImage` references in engine Lua and DRAMATIC_SHAPE are retained, including capability checks and import-time sites. PNG loads are not palette bakes. Gen 3 sections inside shared files remain excluded by X5; the table above identifies the Gen 1/2 functions.

| Site | Operation | Reason / boundary |
| --- | --- | --- |
| [src/battle/AnimPlayer.lua:635](../src/battle/AnimPlayer.lua#L635) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/AnimPlayer.lua:636](../src/battle/AnimPlayer.lua#L636) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/BattleState.lua:676](../src/battle/BattleState.lua#L676) | mapPixel | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:704](../src/battle/BattleState.lua#L704) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:11408](../src/battle/BattleState.lua#L11408) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/BattleState.lua:11499](../src/battle/BattleState.lua#L11499) | newImage | Cached species-palette/cropped picture; balls/HP art PNG loads |
| [src/battle/Gen2AnimPlayer.lua:861](../src/battle/Gen2AnimPlayer.lua#L861) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/Gen2AnimPlayer.lua:862](../src/battle/Gen2AnimPlayer.lua#L862) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/battle/Gen4Battle.lua:3100](../src/battle/Gen4Battle.lua#L3100) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/compat/gen1/AtlasUpload.lua:8](../src/compat/gen1/AtlasUpload.lua#L8) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/FieldEffectRuntime.lua:121](../src/compat/gen1/FieldEffectRuntime.lua#L121) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:187](../src/compat/gen1/SpriteRuntime.lua#L187) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:273](../src/compat/gen1/SpriteRuntime.lua#L273) | mapPixel | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/compat/gen1/SpriteRuntime.lua:288](../src/compat/gen1/SpriteRuntime.lua#L288) | newImage | Native compatibility RGBA upload or explicit mod palette substitution |
| [src/core/TouchControls.lua:214](../src/core/TouchControls.lua#L214) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/core/game3/pokemon.lua:183](../src/core/game3/pokemon.lua#L183) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/core/game3/trainer_pic.lua:25](../src/core/game3/trainer_pic.lua#L25) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/import/AccountWorkspace.lua:35](../src/import/AccountWorkspace.lua#L35) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ArenaPresentation.lua:8](../src/import/ArenaPresentation.lua#L8) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/BankWorkspace.lua:131](../src/import/BankWorkspace.lua#L131) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/CartDesigner.lua:74](../src/import/CartDesigner.lua#L74) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/CartDesigner.lua:102](../src/import/CartDesigner.lua#L102) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/DeveloperWorkspace.lua:27](../src/import/DeveloperWorkspace.lua#L27) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/Gen5MoveAnimData.lua:295](../src/import/Gen5MoveAnimData.lua#L295) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ImageWriter.lua:70](../src/import/ImageWriter.lua#L70) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/ImageWriter.lua:102](../src/import/ImageWriter.lua#L102) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherArt.lua:114](../src/import/LauncherArt.lua#L114) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherCobblemon.lua:20](../src/import/LauncherCobblemon.lua#L20) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherCommunity.lua:479](../src/import/LauncherCommunity.lua#L479) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherJourney.lua:16](../src/import/LauncherJourney.lua#L16) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/LauncherSidebar.lua:1023](../src/import/LauncherSidebar.lua#L1023) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomExtractorGen2.lua:2291](../src/import/RomExtractorGen2.lua#L2291) | mapPixel | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2974](../src/import/RomImporter.lua#L2974) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2975](../src/import/RomImporter.lua#L2975) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2976](../src/import/RomImporter.lua#L2976) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2979](../src/import/RomImporter.lua#L2979) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:2980](../src/import/RomImporter.lua#L2980) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:5652](../src/import/RomImporter.lua#L5652) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/import/RomImporter.lua:11347](../src/import/RomImporter.lua#L11347) | newImage | Import/editor/launcher image construction; outside world-palette switch |
| [src/mods/AssetTransform.lua:73](../src/mods/AssetTransform.lua#L73) | mapPixel | Cached screen/effect artwork PNG load; no world palette bake |
| [src/mods/Loader.lua:1232](../src/mods/Loader.lua#L1232) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/pokemon/Gen5MonAnimPlayer.lua:28](../src/pokemon/Gen5MonAnimPlayer.lua#L28) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/pokemon/PicAnim.lua:98](../src/pokemon/PicAnim.lua#L98) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/pokewalker/WalkerArt.lua:154](../src/pokewalker/WalkerArt.lua#L154) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/render/Assets.lua:123](../src/render/Assets.lua#L123) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/Assets.lua:136](../src/render/Assets.lua#L136) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/Assets.lua:137](../src/render/Assets.lua#L137) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/Assets.lua:142](../src/render/Assets.lua#L142) | newImage | Resolved PNG load, missing-image fallback; no palette mapping |
| [src/render/FontHD.lua:160](../src/render/FontHD.lua#L160) | newImage | Font raster/atlas upload; outside palette switch |
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
| [src/render/Gen4Model.lua:1094](../src/render/Gen4Model.lua#L1094) | mapPixel | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/Gen4Model.lua:1101](../src/render/Gen4Model.lua#L1101) | newImage | Separate Gen 3/4/5 or device path; excluded by X5 |
| [src/render/HudTiles.lua:204](../src/render/HudTiles.lua#L204) | newImage | Native HUD/OBJ tile raster upload |
| [src/render/ShaderGraph.lua:349](../src/render/ShaderGraph.lua#L349) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/render/SpriteRenderer.lua:67](../src/render/SpriteRenderer.lua#L67) | newImage | Cached OBJ palette and color-zero alpha bake |
| [src/render/SpriteRenderer.lua:71](../src/render/SpriteRenderer.lua#L71) | mapPixel | Cached OBJ palette and color-zero alpha bake |
| [src/render/SpriteRenderer.lua:77](../src/render/SpriteRenderer.lua#L77) | newImage | Cached OBJ palette and color-zero alpha bake |
| [src/render/TileRenderer.lua:259](../src/render/TileRenderer.lua#L259) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:290](../src/render/TileRenderer.lua#L290) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:343](../src/render/TileRenderer.lua#L343) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:404](../src/render/TileRenderer.lua#L404) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:757](../src/render/TileRenderer.lua#L757) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:898](../src/render/TileRenderer.lua#L898) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1305](../src/render/TileRenderer.lua#L1305) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1324](../src/render/TileRenderer.lua#L1324) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1344](../src/render/TileRenderer.lua#L1344) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1734](../src/render/TileRenderer.lua#L1734) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1781](../src/render/TileRenderer.lua#L1781) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/render/TileRenderer.lua:1937](../src/render/TileRenderer.lua#L1937) | newImage | Atlas/tile animation/border/keyed-image construction; see table above |
| [src/translation/rompack/title.lua:25](../src/translation/rompack/title.lua#L25) | mapPixel | Cached screen/effect artwork PNG load; no world palette bake |
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
| [src/ui/PokedexMenu.lua:225](../src/ui/PokedexMenu.lua#L225) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
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
| [src/world/OverworldController.lua:16855](../src/world/OverworldController.lua#L16855) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:16858](../src/world/OverworldController.lua#L16858) | mapPixel | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:16865](../src/world/OverworldController.lua#L16865) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17871](../src/world/OverworldController.lua#L17871) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:17945](../src/world/OverworldController.lua#L17945) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18066](../src/world/OverworldController.lua#L18066) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18167](../src/world/OverworldController.lua#L18167) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18334](../src/world/OverworldController.lua#L18334) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18418](../src/world/OverworldController.lua#L18418) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:18452](../src/world/OverworldController.lua#L18452) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
| [src/world/OverworldController.lua:19787](../src/world/OverworldController.lua#L19787) | newImage | Cached screen/effect artwork PNG load; no world palette bake |
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
