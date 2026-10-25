# Deferred macOS OpenGL recovery readback

Follow-up: [verified identical-image reuse](firered-opengl-frame-reuse.md)
reduces the small-window FireRed CPU cost while retaining this pipeline.
The measurements below are the historical `e95748e` comparison.

The detected Cocoa recovery path now starts LÖVE 12's asynchronous texture
readback after presenting the previous completed image. That transfer can run
between frames, instead of making every draw wait immediately for its own
GPU output. There is at most **one outstanding request** and one reusable CPU
image destination. The runtime also needs staging-buffer storage. Healthy
OpenGL, Metal and runtimes without the async API retain their previous path.

This deliberately adds **one frame of presentation latency** to ordinary
recovery frames. Bootstrap displays a complete current image immediately;
that startup image repeats once before the ordered stream advances every
frame. Captures and observers drain the request and receive independently
owned **current-frame** pixels. Restarting afterwards bootstraps again.
Resize and shutdown drain before releasing the image destination or final
texture. Submission/completion failures repair with a synchronous current
image and disable async until resource replacement. No old-image failure
fallback is used.

The implementation uses the pinned runtime's
[asynchronous readback API](https://github.com/love2d/love/blob/937eb3b21f973607ab080aa26b7ef2a6b3b2b663/src/modules/graphics/wrap_Graphics.cpp)
and [OpenGL request implementation](https://github.com/love2d/love/blob/937eb3b21f973607ab080aa26b7ef2a6b3b2b663/src/modules/graphics/opengl/GraphicsReadback.cpp).
The runtime can complete the CPU copy during `graphics.present`; the benchmark
therefore includes presentation in total render time. Its separate readback
metric measures synchronous calls or async submission, **not all completion
work**. Waiting stays in transfer and runtime completion can stay in present.

Eight complete comparisons use an exported `e6a5255` baseline and a candidate
that changes only `WindowFrame.lua`, the same official LÖVE 12 `937eb3b`, no
mods, and fresh fenced task identities. Each game runs AB then BA, with two
real maps at actual 1280×960 and 1920×1440 pixels, 600 warmup and 600 measured
frames per phase: **19,200 timed frames and 32 own-window proofs**. Canonical
NPC and stack signatures match, warmed palette caches remain warm, and native
NPC updates/draws remain enabled. No measured screenshots, observers or pixel
scans run. These are uncapped renders with a 1 ms loop sleep and deterministic
60 Hz simulation on one Apple M3/macOS 15.8.2 host.

The table averages four per-scene P99 values for each game/size; it is **not**
a pooled percentile. CPU is mean process CPU time per frame across those same
phases. Full trials, individual regressions and all metrics remain in the
[metadata report](qa/native-foundation/opengl-deferred-readback.json).

| Game / physical pixels | Mean scene render P99, baseline → deferred | Mean scene interval P99 | Mean CPU/frame change |
| --- | --- | --- | --- |
| FireRed 1280×960 | 10.24 → 8.28 ms (−19.2%) | 11.77 → 10.21 ms | **+8.5%** |
| FireRed 1920×1440 | 12.47 → 9.83 ms (−21.2%) | 14.06 → 11.60 ms | −12.7% |
| Emerald 1280×960 | 10.82 → 7.61 ms (−29.6%) | 12.09 → 8.94 ms | −19.7% |
| Emerald 1920×1440 | 13.54 → 12.39 ms (−8.5%) | 14.96 → 13.93 ms | −3.3% |

This is a tradeoff, not an across-the-board CPU or latency improvement. Small
FireRed costs more CPU on average. Individual large-scene render P99 values
increase 6.3% in one FireRed repeat and 6.3%/8.9% in two Emerald comparisons;
one Emerald phase also costs 8.3% more CPU. Interval tails vary too. External
GPU/compositor load is uncontrolled; the full comparison does not establish
that every individual swing is caused by the source change. Startup,
captures, synchronous fallback and an unfinished async request can still
wait. **GPU stalls are mitigated, not eliminated.**

The ROM-free stream/lifetime/failure suite also checks capture/observer
synchronization, bounded order, resize, startup failures and exceptions.
`tools/check_gen3_palette_gpu.py --backend opengl --async-window-frames` tests
the actual image passed to Cocoa, without enabling synchronous `Frame.observe`.
It checks the changing frame stamp against the declared latency, full scene
colour diversity, movement, captures, resize and map return, plus own-window
OS proofs. The normal current-frame GPU oracle and Metal regressions remain
separate acceptance modes. Ten real-game processes pass: **3,926 continuously
checked frames and 24 own-window proofs**, with zero blank frames or unexpected
stream stamps. The async-specific tests account for 1,292 deferred frames and
16 synchronized current frames. The normal GPU oracle passes **37,358 checks
and 9,522,688 RGBA pixel comparisons** across both games/backends; captures pass
on the first attempt and ROM hashes remain unchanged. The ROM-free runner
passes **107/107 engine suites, 3/3 SDK suites and B30**, including 1,431 async
stream/lifetime/failure checks. Twenty ownership/profile/cache Python tests
also pass. T3 content/link checks skip without a repository ROM import.

Short tests do not establish full gameplay, fullscreen/context-loss or long
session stability, other hardware, displayed FPS or GPU timestamps. Windows
hardware execution is not covered. Only fork exports and owned test processes,
profiles and windows are used; ROM hashes remain unchanged. ROM bytes, derived
images/caches, local paths and process/window identities are not published.
The previously published `native-preview-20261024.1` stays at its original
source. The Origami port remains paused; Gen1 and the player instance are
untouched.
