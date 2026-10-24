# OpenGL recovery performance versus Metal

The macOS OpenGL recovery now avoids a full-window Lua string copy and,
on LÖVE 12, reuses one synchronous readback destination. Both native games
were tested separately against the previous implementation and Metal on
Apple M3 / macOS 15.8.2. This lowers measured CPU cost in the sampled scenes;
it does **not** establish a general FPS improvement or eliminate GPU readback.
Metal remains the lower-CPU option in this comparison.

The subsequent [native palette picture cache](gen3-palette-rebake-cache.md)
addresses the full-atlas rebake bottleneck identified by this checkpoint.
The measurements below describe the earlier window-copy optimization.

## Measured results, 2026-10-24

All primary comparisons use the same official LÖVE 12 development build
`937eb3b21f973607ab080aa26b7ef2a6b3b2b663`, matching actual pixel dimensions,
and the same native maps. Baseline engine: `6e8ef9a`. Each variant/backend/game
has three complete trials. Each table value is the median of the three trial
means, equally averaging two maps at that pixel size. These are **process CPU
milliseconds per rendered frame**, including engine worker CPU time.

| Game / actual pixels | OpenGL before | OpenGL after | CPU reduction | Metal reference |
| --- | ---: | ---: | ---: | ---: |
| Emerald, 1280×960 | 7.29 ms | 5.52 ms | 24% | 4.46 ms |
| Emerald, 1920×1440 | 13.42 ms | 12.83 ms | 4%, noisy | 4.41 ms |
| FireRed, 1280×960 | 4.61 ms | 3.74 ms | 19% | 3.01 ms |
| FireRed, 1920×1440 | 7.89 ms | 5.92 ms | 25% | 2.55 ms |

The mean wall time spent drawing/routing/presenting the frame changes from
7.96 to 6.60 ms for smaller Emerald, 14.41 to 15.11 ms for larger Emerald,
5.28 to 5.30 ms for smaller FireRed, and 9.18 to 8.76 ms for larger FireRed.
Thus reduced CPU allocation/copy cost does not translate into a consistent
wall-time/FPS gain. Large Emerald remains an unresolved performance case.
No performance threshold or long-duration stability guarantee is claimed.

LÖVE 11.5/OpenGL additionally passes separate before/after compatibility
trials for both games at both actual pixel sizes: 4,800 timed frames and
16 fresh OS-window proofs. These single trials are **not** repeated performance
acceptance. Emerald slows severely in the larger after trial (102–114 CPU
ms/frame), so an 11.5 speedup is not claimed. Follow-up replays of the same
lobby show severe slowness on both unchanged baseline (143–153 wall ms/frame)
and candidate (84–132 ms/frame). Texture storage stays at 26,030,848 bytes,
20 images and five canvases in those diagnostic intervals; the sampled
candidate process reports a peak footprint of `391.4M`. This does not indicate
growing texture storage during that short replay.

Instrumentation localizes a remaining native bottleneck: in a separate
180-frame LÖVE 11.5 lobby replay, the existing full-atlas `record.recolor`
path runs 172 times and consumes 17.92 process CPU seconds during 22.30 wall
seconds. That code is identical in baseline and candidate. It rebuilds both
complete atlases when selected palette colours change. Optimizing that
separate renderer path remains open; copying fewer window bytes alone does
not resolve it. The diagnostics establish a pre-existing slow drawing path,
not the exact cause of every variable trial or absence of all regressions.

The [metadata report](qa/native-foundation/window-frame-performance.json)
retains all complete trials, per-scene stage means and tails, CPU times,
actual dimensions, implementation hashes and actual-window proof results.
One optimized Emerald/OpenGL trial slowed severely, including world drawing;
it remains in the statistics. An optimized Emerald/Metal process exited with
code zero before its final report, after three window proofs. Its incomplete
artifacts were preserved and the complete trial repeated. The cause of that
early exit was not established; it is not counted as a completed trial.
No failed image proof is retried or replaced with an earlier good frame.

## What changed

Previously every recovered OpenGL frame created an ImageData, converted its
entire RGBA storage into a Lua string, then copied that string into CFData.
The presenter now passes `ImageData:getFFIPointer()` directly to
[`CFDataCreate`](https://developer.apple.com/documentation/corefoundation/cfdatacreate(_:_:_:)).
CFData still owns a complete immutable copy before the LÖVE buffer can be
released or reused. Core Animation never borrows mutable ImageData storage.
RGBA8 format and exact storage size are checked first.

For ordinary LÖVE 12 recovery frames, the engine additionally fills one
retained ImageData through the runtime's existing
[readback destination argument](https://github.com/love2d/love/blob/937eb3b21f973607ab080aa26b7ef2a6b3b2b663/src/modules/graphics/wrap_Graphics.cpp#L2285-L2319).
It releases that buffer when the canvas size changes or the window-frame
module shuts down. A 1920×1440 RGBA8 buffer holds 11,059,200 bytes: this avoids
churning that destination and the Lua frame string every ordinary frame,
while retaining one working buffer. The GPU transfer and CF-owned image copy
remain necessary. LÖVE 11.5 retains its existing fresh readback path, with
the Lua string conversion removed.

Capture and observer callbacks still receive independent images that are
released after their callback. Ordinary Metal frames continue without any
CPU readback. No resolution reduction, frame skipping, stale-frame reuse,
new public mod API or change to the native game renderer is introduced.

## Method and limits

The primary matrix contains **28,800 timed frames in 24 complete cases** and
**96 actual OS-window proofs** outside the timed intervals. Runs alternate
baseline and optimized variants. Emerald uses the Battle Dome battle room
and lobby; FireRed uses Pallet Town and the player's bedroom. Each trial
tests 640×480 and 960×720 logical windows at Retina scale 2. Each scene/size
gets 120 warmup simulation ticks and 300 measured frames. Native driver
simulation advances deterministically at 60 Hz; rendering is uncapped with
VSync requested and verified zero. The engine's existing 1 ms loop sleep
remains present and is included in inter-frame intervals.

Screenshots, pixel scans, observers and proof markers are absent from timed
intervals. Fresh binary frame markers are drawn only afterward. Capturing
only the test child's own window then verifies current game output, including
ordinary reusable-buffer frames, with independent central-game colour checks.
No observers force an artificial Metal readback during the benchmark.

Wall timers measure CPU queuing, synchronous readback and native window waits,
not GPU timestamps or monitor presentation rate. Metal drawable acquisition
can still block despite requested VSync zero. Stage `transfer` means the
remaining final-target routing/presentation overhead after body and readback;
for Metal it is not a CPU image transfer. Recorded P95/P99 values are per-scene
distributions. Summary P95 entries average the two scene P95s, not a pooled
percentile. The host was not dedicated, external load was not controlled,
and substantial variation also occurred on unchanged Metal code. System
aggregate inspection reported no thermal warning; it did not establish a
cause for the slowdown. The results should not be generalized beyond this
host and these short stationary native scenes.

Each game/backend uses a new task-owned UUID save identity, separately
downloaded runtimes, exported fork source, no mods, and new in-memory game
state. Only imported game-version assets are copied from earlier explicitly
owned fresh-import test identities; saves/options/player caches are excluded.
Legacy migration, identity switches and external cache roots are fenced before
engine startup. The Origami port remains paused. Neither Gen1 nor the protected
player instance is accessed. ROMs, derived images and caches remain private.

## Reproduce

From this checkout, with private supported Emerald/FireRed dumps and Pillow
on macOS, run each backend separately:

```sh
python3 tools/check_gen3_palette_gpu.py --love /path/to/love12 --emerald /path/to/emerald.gba --firered /path/to/firered.gba --backend opengl --window-performance
python3 tools/check_gen3_palette_gpu.py --love /path/to/love12 --emerald /path/to/emerald.gba --firered /path/to/firered.gba --backend metal --window-performance
```

Each invocation performs new full imports into fenced UUID identities. To
measure the original engine with the same current acceptance driver, add
`--engine-ref 6e8ef9a`. The archive's resolved engine commit is recorded in
the private result. The standalone runtime preflight uses the current
checkout's frame module; actual game measurements use the archived engine.
Repeat in alternating order and compare matching actual pixel sizes.

Correctness and compatibility results are recorded alongside the matrix;
they run separately from the performance measurements. ROM-free tests pin
buffer reuse, independent captures, resize/shutdown/failure lifetime and the
native owned-copy contract. This work does not resume Origami porting or
accept First/Third Person, all gameplay, fullscreen, context loss or other
hardware/platforms.

The final ROM-free runner passes **101/101 engine suites, 3/3 mod-SDK suites
and Dramatic Shape B30**. Window ownership/reuse and native-copy tests pass
1,130 + 285 checks; six Python capture-ownership tests, six profile/checker
tests and four cache-policy tests pass. The independent real-ROM GPU palette
oracle passes both games on OpenGL and Metal: **6,006 assertions and 1,498,624
complete RGBA pixel comparisons**, including all four Emerald source phases
and FireRed's 16 native tile frames. Both source ROM hashes remain unchanged.
