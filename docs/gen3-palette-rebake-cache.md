# Bounded native Gen3 palette picture reuse

The native renderer now retains completed CPU atlas pictures for repeating
palette colours. Emerald's Battle Dome no longer has to decode and rebuild
the complete metatile sheets every time a previously seen colour picture
returns. Rendering still uploads the selected pixels into the existing GPU
textures; batches, quads, layer ordering and texture identity remain intact.
No shader, public mod API, source palette, animation clock or save format changes.

Follow-up: [FireRed frame-time investigation](firered-frame-jitter.md) covers
static sampler allocation/collection spikes that remain even with zero atlas
cache entries. Its later measurements and validation are separate from the
historical comparison below.

## Cache and lifetime

`Gen3PaletteFrameCache` is a CPU-only LRU with at most four colour pictures
per tileset-pair owner and **32 MiB of retained RGBA payload globally**.
A picture contains the complete bottom/top atlases, all their tile-animation
slots, and the reflection-cover atlas when present. The key is the native
palette sampler's exact complete RGB content key, not the current tick or
only one cycle's phase number. Identical colours therefore reuse identical
pictures even with independent overlapping palette programs.

The initial bake primes its current picture. A new colour picture is built
and uploaded normally; only a completed rebuild enters the cache. A hit
uploads the retained ImageData without decoding metatiles again. Temporary
surfaces from failed uploads are released and the decoder's selected tile
animation picture is restored. GPU upload failures still propagate; this
does not make GPU updates transactional.

Initially static or legacy tilesets retain no cached colour pictures. Invalid metadata
drops that owner's old pictures and uses the existing base-colour fallback.
Asset invalidation, imported-source reset and tileset eviction release CPU
pictures. A cache-pressure eviction releases CPU storage while keeping the
owner's live GPU textures valid. Sheet eviction also releases its associated
reflection texture. Re-imported pairs use new owners, so equal pair names
cannot recover another source's pictures.

The retained-payload limit excludes ordinary GPU textures, Lua bookkeeping,
transient bake tables and in-flight upload allocations. Larger pictures that
cannot fit the budget follow the existing uncached path. Programs with more
than four distinct pictures or pressure from other owners may require new
bakes after eviction. Initial/cold bakes still cost time; the steady-state
measurements below exclude warmup rather than claiming faster initial loading.

## Validation

The [metadata report](qa/native-foundation/palette-rebake-performance.json)
records the actual before/after native-game trials. Baseline is `cdfda7e`;
candidate source changes only the native tileset renderer and CPU picture
cache. All primary comparisons use official LÖVE 12 development build
`937eb3b21f973607ab080aa26b7ef2a6b3b2b663`, Apple M3 and macOS 15.8.2.
Both backends use the same actual 1280×960 and 1920×1440 pixel sizes.

Median process CPU and frame-render wall milliseconds, before → after:

| Emerald / actual pixels | CPU ms/frame | Render/present wall ms/frame |
| --- | ---: | ---: |
| OpenGL, 1280×960 | 30.17 → 11.18 (−63%) | 32.95 → 16.35 |
| OpenGL, 1920×1440 | 53.35 → 17.13 (−68%) | 55.89 → 21.09 |
| Metal, 1280×960 | 31.69 → 3.04 (−90%) | 33.23 → 7.07 |
| Metal, 1920×1440 | 21.69 → 4.04 (−81%) | 29.00 → 8.78 |

Each summary is the median of three trial means, each equally averaging the
two maps at one pixel size. All trial data, including slow runs and per-scene
P95/P99/maxima, remain in the report. The warmed optimized Emerald intervals
contain **1,502 picture reuses and zero misses/rebakes** in 7,200 timed frames.
Its native palette clock remains wall-time driven: slow baseline frames may
cross more colour changes per frame. The cache breaks that repeated-rebuild
feedback; these are native frame measurements rather than an isolated memcpy
benchmark or a claim about GPU-only time.

FireRed's pixel/animation regression checks pass, with zero cache entries,
hits or misses in its static terrain. Timing controls vary substantially.

| FireRed / actual pixels | CPU ms/frame | Render/present wall ms/frame |
| --- | ---: | ---: |
| OpenGL, 1280×960 | 12.81 → 12.08 | 15.01 → 13.79 |
| OpenGL, 1920×1440 | 14.18 → 17.89 | 16.15 → 19.59 |
| Metal, 1280×960 | 5.55 → 4.27 | 8.31 → 9.66 |
| Metal, 1920×1440 | 4.16 → 3.84 | 9.55 → 9.61 |

The primary 1920×1440 OpenGL control has CPU 14.18 → 17.89 ms (+26%) and
render/present wall time 16.15 → 19.59 ms (+21%). A predeclared follow-up tests
that same high-resolution case in AB/BA/AB order, 3,600 additional frames and
12 own-window proofs: CPU medians 18.23 → 18.61 ms (+2.1%) and wall medians
22.56 → 20.86 ms (−7.5%). The large slowdown does not reproduce consistently;
trial variation exceeds the follow-up differences. This is not evidence of
a general FireRed speedup or proof that every small regression is absent on
this non-dedicated host. Its native static palette revision remains zero.

Three alternating baseline/optimized trials per game/backend cover the real
Battle Dome room/lobby in Emerald and Pallet Town/player's bedroom in FireRed.
Each scene/size has 120 warmup simulation ticks and 300 timed frames. The
primary matrix comprises 28,800 timed frames and 96 actual OS-window proofs.
The driver uses the engine's existing deterministic 60 Hz simulation with
uncapped rendering, requested/verified VSync zero and its existing 1 ms loop
sleep. CPU measurements include engine worker threads; wall sections include
queueing, synchronous readback and native drawable waits. These are not GPU
timestamps or monitor FPS. Metal can still wait for drawable availability.

No screenshots, observers, pixel scans or proof markers run inside timed
intervals. Fresh markers and central-game colour checks verify only the test
child's own actual window afterward. Raw trials and tails are retained;
external host load is uncontrolled. One incomplete FireRed/Metal trial was
preserved after the OS screenshot tool timed out after 15 seconds, then
repeated completely. Completed trials were not discarded.

The four Emerald pictures occupy **8,454,144 RGBA bytes (8.0625 MiB)** for the
tested pair, independent of window size. The measured warmed intervals check
zero cache misses/full rebuilds. FireRed's audited static terrain programs
occupy zero cache entries. This is source-specific native presentation
acceptance, not a promise for every custom palette program or platform.

ROM-free coverage checks global/per-owner pressure and exactly-once CPU
release, independent pixel decoding of every layer and tile variant, cached
reflection pixels, GPU identity, unchanged borders/batches, repeated cycles
without rebaking, failed-upload cleanup, invalid metadata and source/asset
invalidation. The real-ROM GPU oracle additionally checks reflection-cover
pixels against an independent decoder, alongside its existing complete RGBA
atlas/floor checks, four Emerald source phases and all 16 FireRed tile frames.

## Reproduction and isolation

Use the performance launcher from a committed checkout, a separately installed
LÖVE runtime and the supported private Emerald/FireRed dumps. macOS own-window
proofs require Pillow and existing screen-capture access:

```sh
python3 tools/check_gen3_palette_gpu.py --love /path/to/love12 --emerald /path/to/emerald.gba --firered /path/to/firered.gba --backend opengl --window-performance
python3 tools/check_gen3_palette_gpu.py --love /path/to/love12 --emerald /path/to/emerald.gba --firered /path/to/firered.gba --backend metal --window-performance
```

Add `--engine-ref cdfda7e` for the baseline engine with the same current
acceptance driver. Omit `--window-performance` for the independent GPU pixel
oracle. The native diagnostic `TileRenderer.gen3PaletteCacheStats()` exposes
detached counters only; it is not a public mod contract. The benchmark records
these counters outside the timed intervals.

The public launcher performs new full imports. This comparison instead copies
only authenticated game-version assets/data and the import completion marker
from earlier explicitly owned test imports into new UUID identities. It uses
new in-memory game state, source exports and task-owned runtime downloads.
No saves, options, player cache or mods are loaded. The bootstrap fences legacy
migration, identity changes and external/portable cache roots before main.
ROMs, images, caches, local paths and process/window identifiers remain private.
The Origami port stays paused; Gen1 and the protected player instance are
untouched. Full gameplay, First/Third Person, fullscreen/context loss and other
hardware/platforms remain separate acceptance work.

Final checks: **102/102 engine suites, 3/3 mod-SDK suites and Dramatic Shape
B30 pass**, including 622 cache-pressure/ownership checks and the expanded
native pixel/lifetime suite. Six ownership, six profile/checker and four
cache-policy Python tests pass; Lua parsing and whitespace checks pass.
Separate LÖVE 11.5 OpenGL candidate runs add 2,400 frames and eight actual
OS-window proofs for both games, with zero warmed Emerald misses. The real-ROM
GPU oracle passes all three backend/runtime configurations: **56,037 assertions
and 14,284,032 complete RGBA pixel comparisons**, including 12,036,096 reflection
cover pixels. All oracle captures pass on their first attempt. Map return,
retained texture identities, FireRed indoor movement and all 16 tile frames
pass. Both source ROM hashes remain unchanged; no paired 11.5 speedup is claimed.
