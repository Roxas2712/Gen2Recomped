# FireRed frame-time investigation

The native renderer sampled and copied both complete 16×16 RGB palette banks
on every terrain tick, even when the authenticated FireRed import explicitly
reported no palette programmes. Pallet Town also renders resident neighbour
pairs, multiplying this allocation traffic. The earlier atlas-picture cache
correctly retained zero FireRed pictures; that did not avoid these sampler
allocations.

A live LuaJIT sampling profile localised palette-copy/packing and collection
work inside the draw. Individual baseline Metal draw spikes reached 7.6 ms
while the Lua heap dropped, and OpenGL showed the same allocation path. Native
OpenGL readback/Cocoa presentation and Metal drawable/present waits appeared
separately. This identifies a removable source of renderer spikes; it does
not establish that every earlier slow whole-window trial had the same cause.

## Change

`Gen3Tiles:setPaletteTicks` reuses its owned static sample only after checking
both source banks against all 1,536 packed RGB bytes, validating every palette,
colour and empty programme-list shape. The terrain clock still advances.
Missing/invalid metadata, edited values, changed programme lists, invalid
clocks or invalid bank splits leave this path and use the existing full
sampler. Same-table edits therefore remain observable; source identity alone
is never treated as proof of unchanged pixels. The public colour snapshot
sampler continues to return detached results.

This adds no retained palette-picture cache, changes no GPU texture identity,
shader, simulation clock, render resolution, presentation policy or import
format. Animated Emerald palette programmes continue through the original
sampler and bounded atlas-picture cache.

## Acceptance method

The baseline is `f3fe09fad376983cb6d5ed60ac21d8183385b9ec`. Both variants use
the same current benchmark driver, official LÖVE 12 build `937eb3b` and an Apple
M3 running macOS 15.8.2. Both games use a declared AB/BA order. Each
game/backend trial visits two real maps at actual 1280×960
and 1920×1440 pixels, with 120 warmup ticks and 300 timed frames per phase.

The driver records game update, incremental collection, palette synchronisation,
draw body, frame readback, transfer, present and frame intervals. The palette
and collection sections are nested costs, not numbers to add to total render
time. CPU is process CPU and includes worker threads. Wall timers include
queuing and native waits; they are not GPU timestamps or displayed FPS.
The existing deterministic 60 Hz driver runs uncapped with VSync explicitly
set to zero and the engine's 1 ms loop sleep. Native drawable backpressure can
still occur. Each rendered frame advances game/audio update by 1/60 second;
this is not a wall-time 60 Hz gameplay run. Native terrain animation keeps
its existing wall-time clock. No observers, screenshots, marker drawing or pixel scans occur
inside measured intervals. Every phase has a fresh-marker proof in its own
actual OS window after timing, with owner PID checked by the launcher.

Both RNGs are seeded per phase. FireRed's benchmark additionally sorts the
computed neighbour placements before NPC construction and starts with a fresh
test NPC pool. An unordered connection traversal otherwise assigns constructor
RNG draws to different NPCs, and retained actors can keep earlier states.
This changes only scene setup in the test driver; no NPC update/draw methods
are replaced. Exact home/ghost NPC signatures are checked before and after
every final interval across variants, repeats and backends. Emerald uses the
unchanged seeded setup; per-trial driver hashes record that distinction.

A separate bounded allocation probe runs **after all timed phases and window
proofs**. It uses a new decoder over the actual
resident imported banks: one initial sample, then 120 palette ticks with
automatic collection stopped. It reports Lua heap increase per tick, including
small JIT/bookkeeping allocations. This prevents the probe from changing JIT
or collector state before the timed workload. It measures sampler allocation,
not total frame/GPU memory. Every complete timing trial is retained.

The metadata also keeps both earlier matrices and all eight seed-only FireRed
trials separately. Their smaller draw tails but mixed total CPU timings are
not hidden. One seed-only OpenGL pair had unequal NPC signatures; none of
those preliminary trials is mixed into the final comparison.

[Full metadata and distributions](qa/native-foundation/firered-frame-jitter.json)
contain the final measurements and source hashes.

## Results

Final acceptance covers **19,200 timed frames and 64 actual own-window proofs**.
All 64 phase signatures match across final variants, repeats and backends.
FireRed sampler allocation falls from **72.21–72.35 KiB to 0.0013–0.0395 KiB
per static tick** in the bounded actual-source probe. The earlier allocation
probe timing placement and unequal NPC workloads are corrected in this comparison.

| Game / backend / pixels | Draw-tail ms before → after | Process CPU ms before → after | Render/present wall ms before → after |
| --- | ---: | ---: | ---: |
| firered / OpenGL / 1280×960 | 2.136 → 0.869 | 3.728 → 3.938 | 5.521 → 5.444 |
| firered / OpenGL / 1920×1440 | 1.731 → 0.791 | 5.972 → 6.196 | 7.920 → 7.963 |
| firered / Metal / 1280×960 | 2.628 → 1.129 | 2.383 → 2.173 | 6.662 → 6.722 |
| firered / Metal / 1920×1440 | 2.681 → 1.058 | 2.294 → 2.260 | 6.660 → 6.792 |
| emerald / OpenGL / 1280×960 | 5.040 → 4.384 | 3.698 → 3.766 | 5.543 → 6.087 |
| emerald / OpenGL / 1920×1440 | 7.827 → 7.127 | 6.264 → 6.386 | 9.374 → 9.582 |
| emerald / Metal / 1280×960 | 3.944 → 3.962 | 2.292 → 2.442 | 6.960 → 6.950 |
| emerald / Metal / 1920×1440 | 4.106 → 3.960 | 2.023 → 2.511 | 7.002 → 6.990 |

Draw-tail values are medians of trial averages of the two map P99s, **not a
pooled P99**. FireRed draw tails fall **54–61%** and mean palette synchronisation
falls **81–86%**. These reductions do not imply an overall FPS gain: final
OpenGL process CPU is 4–6% higher, while Metal process CPU is 1–9% lower.
Native readback, image transfer and drawable/present waits remain.

**Emerald functional/GPU checks pass; performance parity is not established.**
The high-resolution Metal CPU summary rises 24.1% (2.023 → 2.511 ms), although
render/present wall time is essentially unchanged. A separate same-process
Metal diagnostic switches only the old/new palette method in AB/BA order
for another 2,400 frames. It does not show a consistent candidate CPU penalty
(candidate average 1.102 vs baseline 1.139 ms), but its NPC signatures differ,
so it cannot establish a causal throughput comparison. A performance regression
cannot be excluded from these short trials. The visible Battle Dome world may
also have its native entry TextBox on top; full Battle Frontier gameplay is
not part of this graphics acceptance.

The independent real-ROM GPU oracle passes **37,358 assertions and 9,522,688
complete RGBA pixel comparisons**, including 8,024,064 reflection-cover pixels,
across both games on OpenGL and Metal. All 18 captures pass first attempt.
Emerald source phases/live floor, FireRed native tile frames, retained GPU
identities, map return and FireRed indoor movement pass. Warmed Emerald atlas
misses remain zero; FireRed retains zero atlas pictures. Both ROM hashes remain
unchanged. The current ROM-free runner passes **103/103 engine suites, 3/3 SDK
suites and B30**, including 2,448 static-reuse/mutable-source checks. Six ownership,
six palette-profile and four cache-policy Python tests, Lua parsing and
whitespace checks pass.

## Isolation and limits

Runs use source exports, task-owned runtime downloads, fresh UUID identities
and new in-memory game state. Only assets/data and the import completion
marker from prior explicitly owned test imports are copied. No saves, options,
mods or player cache are loaded. Legacy migration, identity changes and
external/portable roots are fenced before engine startup. Screenshots select
only the test child's reported window. Cartridge bytes, derived images/caches,
local paths and process/window IDs stay private.

This is one non-dedicated host; external load is not controlled. The static
allocation fix does not remove full-frame OpenGL readback/Cocoa image transfer
or Metal drawable/present waits. Larger prior end-to-end swings were not
reliably reproduced here, so complete elimination of timing variation is not
claimed. Full gameplay, long-duration/fullscreen/context-loss behaviour,
other hardware and First/Third Person remain outside this native flat-world
acceptance. The Origami port remains paused; Gen1 and the protected player
instance are untouched.

Reproduce with `tools/check_gen3_palette_gpu.py --window-performance` and the
same private supported ROMs and separate LÖVE runtime, once for `--backend
opengl` and once for `--backend metal`. Add `--engine-ref f3fe09f` for the baseline.
The launcher performs fresh imports rather than loading a player cache.

The subsequent [Emerald Metal CPU investigation](emerald-metal-cpu.md) addresses
animated sample copying, adds separate main-thread CPU measurements and longer
matched workload trials, and fixes inherited macOS presenter CType exhaustion
found during FireRed regression checks. Its current results and negative timing
controls supersede performance inferences from this earlier short comparison;
the historical measurements above remain unchanged.
