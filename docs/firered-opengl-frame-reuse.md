# FireRed small-window OpenGL CPU

The presenter repeatedly copied and committed complete images even when the
new GPU readback had exactly the same pixels. The Cocoa recovery path now
retains one immutable CFData snapshot of its last successful presentation.
It still reads every complete GPU frame and converts RGBA to BGRA, then uses
native `memcmp` across **every byte**. Only identical pixels with unchanged
pixel/point geometry and the same owning view can omit another CFData copy,
CGImage creation and Core Animation commit. There are no hashes or address-only
checks. Any changed byte or geometry forces presentation.

The retained snapshot is replaced only after successful presentation and is
released on view replacement/shutdown. Failed allocation/conversion/image
creation cannot become the comparison reference. The existing async pipeline,
one-frame latency, current-frame captures/observers, GPU readback frequency,
native NPC simulation and palette caches keep their semantics. One immutable
full-frame snapshot is retained: 4.69 MiB at 1280×960 or 10.55 MiB at 1920×1440,
separate from existing scratch/readback buffers and palette cache budgets.

The [complete metadata](qa/native-foundation/firered-opengl-frame-reuse.json)
compares exported `e95748e` with a candidate differing only in
`MacWindowSurface.lua`, using official LÖVE 12 `937eb3b`, no mods and fresh fenced
task profiles. Eight AB/BA trials cover two maps at two physical sizes in each
game, 600 warmup/600 measured frames per phase: **19,200 timed frames and 32
own-window proofs**. Canonical NPC/stack signatures match; warmed palette
caches remain warm. No screenshots, observers or pixel scans run during timing.
The benchmark is uncapped with a 1 ms sleep and deterministic 60 Hz simulation.

| Game / physical size | Mean process CPU/frame | Mean main-thread CPU change | Mean scene render P99 |
| --- | --- | --- | --- |
| FireRed 1280×960 | 3.39 → 2.42 ms (−28.6%) | −29.2% | **8.00 → 8.84 ms (+10.5%)** |
| FireRed 1920×1440 | 4.36 → 2.93 ms (−32.8%) | −33.3% | 10.12 → 8.19 ms |
| Emerald 1280×960 | 5.76 → 3.92 ms (−32.0%) | −30.9% | 17.54 → 10.47 ms |
| Emerald 1920×1440 | 12.21 → 6.60 ms (−46.0%) | −40.3% | 31.96 → 17.79 ms |

CPU/frame improves in both complete pairs at every size. FireRed small-window
process CPU improves about 30.4% and 27.0% in its two pairs. P99 summaries are
arithmetic means of four scene percentiles, **not pooled P99s**. Small FireRed's
average tail is worse despite lower CPU; its bedroom render P99 increases
62.2% in one repeat. One small Emerald phase costs 4.1% more process CPU and
has 58.2% higher render P99; another large Emerald scene P99 increases 10.2%.
All positive deltas are retained. Emerald absolute timings vary substantially;
uncontrolled host/GPU/compositor load prevents attributing every swing to the
source change. Do not pool absolute results with earlier reports. GPU waits
remain possible; this fixes repeated CPU work, not every timing tail.

An instrumented baseline diagnostic locates material work in CFData creation
and image commit; its instrumentation is excluded from primary acceptance.
A same-process native ABBA/BAAB control uses one captured real FireRed frame,
changes its last red byte every other call, and compares both presenters over
eight blocks of 100 warmup/240 measured calls. CPU improves in both block
pairs; the fixture is deliberately modified during this test and restored at
the end. Native pixel/lifetime tests additionally compare **51,200 bytes**,
all alpha values, actual image dimensions, equal-size reshapes, retained old
CGImages, identical snapshot reuse and shutdown.

The rejected direct native-allocation/no-copy-CFData proposal was byte/lifetime
correct but gave no reliable real-game CPU improvement in short pilots. It is
not shipped. Its measurements and the frozen-frame control are retained in
the report rather than presented as an accepted optimization.

Real-game functional acceptance includes ordinary changing frame stamps,
repeat-stamp sequences that exercise actual immutable image reuse, independent
current-frame OpenGL and Metal checks, movement/captures/resize/map return and
own-window OS captures: **5,279 checked frames / 32 own-window proofs**, zero
blank/unexpected stream images and 804 verified image reuses. The current-frame
GPU oracle passes **37,358 checks / 9,522,688 RGBA pixel comparisons**, with
first-attempt captures and unchanged ROM hashes. Reproduce the reuse branch with
`tools/check_gen3_palette_gpu.py --backend opengl --async-window-frames --repeat-window-stamps`
plus the normal ROM/runtime/output arguments. All live totals are in the
report. The ROM-free runner passes **107/107 engine suites, 3 SDK suites and
B30**; twenty ownership/profile/cache Python tests pass. Presenter boundary
checks cover 1,296 pixel/lifetime/failure assertions and 108 ABI/lifetime checks,
including 12,000 changed and 1,000 equal presents without additional function
pointer casts. Repository T3 content/link checks skip without a ROM import.

Only fork exports and owned test processes/profiles/windows are used. No player
saves/options or external mods are loaded. ROM bytes, images/caches, private
paths and process/window IDs are not published. One Apple M3/macOS 15.8.2 host
and short native scenes do not establish full gameplay, fullscreen/context
loss, long-duration stability or Windows hardware acceptance. The Origami
port remains paused; Gen1 and the player instance are untouched.
