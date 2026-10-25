# FireRed OpenGL presentation CPU

The previous palette investigation left FireRed's complete OpenGL CPU cost
unresolved. Its static palette method was unchanged and inexpensive, while
end-to-end trials varied substantially. This follow-up profiles the current
engine and changes only the detected macOS OpenGL recovery presenter. The
Origami port remains paused; Gen1 and the protected player instance are untouched.

## Cause and change

Main-thread CPU instrumentation separates normal world drawing, game updates,
palette checks, synchronous readback and native image presentation. At actual
1920×1440 pixels, the baseline presenter consumes about 2.8–3.1 CPU ms/frame;
world drawing takes about 0.14–0.56 ms and palette checks much less. A second,
native-call profile localises about 2.23–2.25 ms to `CATransaction.commit`,
compared with about 0.60–0.61 ms in the immutable `CFDataCreate` copy. Removing
only the palette work cannot address this presentation cost. Profile wrappers
perturb execution and establish localisation, not the primary speedup result.

The presenter now uses Accelerate's `vImagePermuteChannels_ARGB8888` to reorder
RGBA bytes into BGRA with the exact permutation `{2,1,0,3}`. No colour values,
alpha values or precision change. The CGImage declares little-endian
premultiplied-first storage (`0x2002`) instead of premultiplied-last RGBA.
This replaces the expensive RGBA presentation path with the native BGRA path.
The conclusion about format conversion follows from the native-call profile
and the same-process format-path comparison; it is not a claim about a
particular private Core Animation implementation.

Apple documents [native BGRA formats](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_texturedata/opengl_texturedata.html)
and [BGRA bitmap layout](https://developer.apple.com/documentation/accelerate/vimage_cgimageformat/bitmapinfo?language=objc).
The vImage buffer/function ABI and `kvImageDoNotTile` are checked against the
installed macOS SDK headers. The shuffle runs without internal worker tiling;
no new worker scheduling or Lua pixel loop is introduced.

One independent ByteData scratch buffer holds the current converted frame and
is reused while the byte extent matches. Width, height and stride are supplied
from the current image on every call, including equal-byte-size reshapes. A
replacement allocation succeeds before the previous buffer is released. View
replacement and shutdown release it; a conversion error propagates before a
partial or stale frame can be presented. At 1920×1440 this adds one 11,059,200
byte (10.55 MiB) CPU working buffer, separate from the unchanged RGBA readback
buffer and the palette-atlas cache budget.

CFData still takes a complete immutable copy before return. Core Animation
never borrows either mutable LÖVE buffer. The original RGBA ImageData remains
unchanged for captures and observers. All seven Objective-C function-pointer
ABIs remain bound once. No window/frame boundary, shader, palette sampler,
clock, resolution, frame count or native game update/draw function changes.
Metal's ordinary GPU frame path never invokes this presenter.

## Method

The baseline is `50e5fb0cfc9b1dc3b96dee583047430b986a26c1`. Both variants use
the same official LÖVE 12 `937eb3b21f973607ab080aa26b7ef2a6b3b2b663` on
Apple M3 / macOS 15.8.2. Source exports differ only in `MacWindowSurface.lua`.
The exports exclude mods and `POKEPORT_NO_MODS=1` independently disables mod
discovery. This differs from the previous investigation's frozen shipped-mod
controls; absolute numbers across the two reports are not pooled.

The primary comparison uses two complete pairs per game in AB/BA order, two
real maps and two actual physical window sizes, 1280×960 and 1920×1440. Every
scene gets 600 warmup simulation ticks and 600 measured frames. Simulation
advances 1/60 second per rendered frame; the native terrain clock keeps wall
time. VSync is requested and checked zero and the normal 1 ms loop sleep stays.
No observer, capture, pixel scan or proof marker runs inside timing. Own-window
proofs follow each phase. Allocation probes run after all timing and proofs.

Both RNGs are seeded, returned neighbour construction placements are sorted,
and only the test instance's NPC pool is reset. Canonical NPC identities,
sprites, placements and state and the stack before/after each scene must match
across variants. Actual native NPC update/draw functions remain intact. Emerald
Battle Dome can show its native entry TextBox over the animated world; this is
native graphics acceptance rather than full Battle Frontier gameplay.

Main-thread CPU uses `CLOCK_THREAD_CPUTIME_ID`; process CPU includes engine
workers. Wall intervals include native queuing and waits and are not GPU
timestamps or displayed FPS. Summary values are medians of per-trial means,
each equally averaging the two maps at the same pixel size. Per-scene tail
summaries are not pooled percentiles.

An independent same-process method comparison presents the same complete
1920×1440 captured FireRed frame in AB/BA order, 30 warmup calls then 300 calls
per block with automatic GC. Common FFI declarations are installed once before
both module versions are initialised; the old module uses those same ABI
declarations. No FFI setup runs inside the measured blocks. Game rendering,
updates and readback do not run inside those method intervals, so these
results isolate presenter work, not total gameplay throughput. The RGBA source
is compared byte-for-byte afterwards.

## Results on this host

The primary comparison completes **19,200 measured frames and 32 own-window
proofs**, with matched canonical NPC and stack signatures in every scene.
Values below are whole-process CPU ms per rendered frame (two pairs per game,
median of trial map-averages). All individual trials remain in the
[metadata report](qa/native-foundation/firered-opengl-cpu.json).

| Game / actual pixels | Before | After | Change |
| --- | ---: | ---: | ---: |
| FireRed, 1280×960 | 3.596 ms | 3.159 ms | −12.1% |
| FireRed, 1920×1440 | 5.552 ms | 4.875 ms | −12.2% |
| Emerald, 1280×960 | 3.774 ms | 3.133 ms | −17.0% |
| Emerald, 1920×1440 | 5.991 ms | 5.103 ms | −14.8% |

Main-thread CPU falls 13.6%/13.0% for FireRed and 19.0%/15.9% for Emerald.
Both complete pairs improve at each size in both games. In the same-process
presenter control, baseline calls take 2.988/2.517 ms and new calls 1.534/1.559 ms
(about 44% lower presenter CPU). The RGBA source remains byte-for-byte identical.
The candidate native-call profile records approximately 0.28–0.37 ms for the
shuffle and 0.97–1.04 ms for commit at 1920×1440, rather than 2.23–2.25 ms for
the baseline commit. Instrumented costs are not pooled with primary trials.

Not every metric improves. FireRed's smaller-window render P99 changes +1.2%
and interval P99 +0.6%; the larger-window unchanged draw-body mean is +31.3%.
Emerald's synchronous readback wall means are +4.2–4.7% despite lower total CPU
and lower render/interval means. All stage means and tails are retained. The
fix removes measured avoidable presentation cost; it does not establish zero
variance, that every stage improves, or an FPS guarantee.

Every ordinary measured OpenGL frame still reads its current complete target:
600 readbacks per phase, with no frame skipping or stale-picture reuse.
Warmed Emerald has four palette samples, zero full samples and zero sample/
atlas misses. FireRed creates no palette sample cache and has zero full
samples/atlas pictures. The palette code is identical in both variants.

Final-source window tests pass **2,623 continuously checked frames and sixteen
additional own-window proofs** across both games on OpenGL and Metal. There
are zero blank/stale frames or retries; movement, resize and map return pass.
The independent real-ROM oracle passes **37,358 assertions / 9,522,688 complete
RGBA pixel comparisons**, including **8,024,064 reflection-cover pixels**. All
18 captures pass first attempt. Emerald source palette phases/live floor,
FireRed native tile frames, retained GPU identities, map return and FireRed
indoor movement pass. Both ROM hashes remain unchanged. Metal receives
functional regression acceptance here; its ordinary frame path is unchanged
and no new Metal performance comparison is claimed.

A separate actual Accelerate/ByteData probe compares **20,480 bytes**, including
all alpha values, exact channel permutation, unchanged source data, same-byte-
size reshape, resize and shutdown. ROM-free checks pass **105/105 engine
suites, 3/3 SDK suites and B30**. The presenter suite passes 737 checks covering
CF-owned immutable storage, channels/alpha, scratch reuse and failed allocation/
conversion cleanup. The type-lifetime suite still drives 12,000 presents and
100 window lookups without further function-pointer casts. Six ownership,
six palette-profile and four cache-policy Python tests, three Lua file parses
and whitespace checks pass. Repository T3 content/link checks skip without an
import in the checkout; actual-ROM acceptance uses separate test identities.

The preliminary exploratory AB pair is preserved separately from the hardened
final-source trials. There are no failed or incomplete cases in this follow-up.

## Isolation and limits

All runs use exported fork source, task-owned runtime binaries and fresh fenced
UUID identities. Only assets/data and the completion marker from earlier
explicitly owned imports are copied. No player saves/options/cache or external
mods are read. Legacy migration, identity changes and external/portable roots
are rejected before main. Actual OS captures select only the window reported
by the currently owned test child and verify its process identity first.
ROM bytes, generated assets, images, local paths and process/window IDs remain
private. Source ROM hashes are rechecked after GPU acceptance.

One non-dedicated host and short stationary scenes do not establish universal
FPS, long-duration/fullscreen/context-loss stability or other-platform speed.
Synchronous OpenGL readback and immutable native image copying remain costs.
This does not resume First/Third Person or other Origami porting work.

## Reproduce

Use `tools/check_gen3_palette_gpu.py --window-performance --backend opengl`
with the pinned runtime and supported private ROMs; repeat in AB/BA order with
and without `--engine-ref 50e5fb0`. The launcher exports no mods, performs fresh
imports into fenced identities and records actual dimensions/source revision.
Use `--window-frames` and each backend for functional window acceptance; omit
both flags for the independent ROM-palette GPU oracle. No player import or
instance needs to be used.
