# Native animated palette CPU work

Emerald's native palette animation still copied both complete 16×16 RGB banks,
selected the program frames and packed both RGB strings every terrain tick.
The atlas cache avoided rebuilding GPU pictures, but did not avoid this work.
FireRed's explicit static palettes already reused their owned sample. Metal
also has native drawable waits and worker CPU, so a higher **process** CPU
measurement alone does not identify which renderer work changed.

The investigation separates main-thread CPU (`CLOCK_THREAD_CPUTIME_ID` on
macOS) from process CPU, records palette work and collector samples, and uses
a direct old/new method comparison over the same actual loaded Emerald banks.
The initial profile localised repeated colour-copy/packing and collection in
`Gen3PaletteCycles.sample`. Profile timers perturb execution; their absolute
costs are diagnostic, not the speedup result.

## Implementation

`Gen3PaletteSamples` retains at most **four owned palette states per animated
native decoder**. A hit reuses the RGB tables, packed strings and selected
frame arrays, advances the private sample's tick, and preserves the same
content key. It retains no GPU resources. The separate atlas-picture LRU
continues to upload into the same existing GPU textures.

Every lookup first checks both current banks by value: complete palette and
RGB tuple shapes, every base RGB byte, palette split, all relevant program
fields, all frame-array shapes and every immutable frame string. Neither
source-table identity nor the currently displayed colours establish validity.
Same-table edits, future-frame edits, cadence/phase/direction changes, missing
metadata and invalid clocks therefore cannot reuse stale pictures. New states
use the existing full sampler; source changes flush retained states. LRU
pressure evicts rather than growing beyond four states. Inputs with more than
four recurring combinations may still need full sampling.

Initially static FireRed uses the existing static fast path and creates no
new sample cache. The public `Gen3PaletteCycles.sample` and mod snapshots
remain detached and unchanged. No shader, import, save, render resolution,
clock, native presentation policy or player-instance change is involved.

## Measurement and acceptance

The baseline is `beb70f3b05a57b9fd3ec7f19352b43d7f7bc228e`. Both variants use
the same official LÖVE 12 `937eb3b` runtime on Apple M3 / macOS 15.8.2.
The main comparison uses 600 warmup ticks and 600 measured rendered frames
per phase, two real maps and actual 1280×960/1920×1440 pixels. Emerald/Metal
uses AB/BA/AB; FireRed/Metal uses AB/BA and FireRed/OpenGL uses AB/BA/AB.

The sixteen completed cases contain **38,400 timed frames and 64 own-window
proofs**. These private source exports include the same tracked repository
mod, `Gen2Recomped-DramaticShapes` 0.7.71, in both variants; all 200 files have
an identical aggregate digest. The native flat renderer is selected. No player
or external mods are loaded. This differs from the public launcher's export,
which deliberately omits `mods`; the separate no-mod controls below use
`POKEPORT_NO_MODS=1`. The full source exports differ only in the three recorded
production modules (the original baseline omits the new sample module).

Both RNGs are seeded per scene, returned neighbour placements are sorted
before actor construction, and only the test instance's NPC pool is reset.
NPC identities, sprites, placements and state are recorded canonically, so
an entry script appending equivalent actors in a different list order does
not become a false workload mismatch. Stack state is recorded too. No native
NPC update/draw methods are patched. Battle Dome can show its entry TextBox
over the visible animated world; this is graphics acceptance, not full Battle
Frontier gameplay.

Game/audio update advances 1/60 second per rendered frame; terrain keeps its
native wall-time clock. Rendering is uncapped, VSync is explicitly zero, and
the main loop keeps its existing 1 ms sleep. Wall queue/wait times are not GPU
timestamps or displayed FPS. Process CPU includes engine workers; the added
main-thread CPU clock measures the thread running Lua and graphics calls.
No observer, capture, marker drawing or pixel scan occurs inside timing.
Fresh-marker proofs in the current child process's own OS window follow every
phase. Bounded allocation probes run after all timing and window proofs.

A separate controlled method microbenchmark runs the old and new methods in
AB/BA order on the same resident cartridge-derived banks, two thousand calls
per block after warmup, with automatic GC enabled during CPU timing. It
measures main-thread method CPU, not gameplay FPS. Allocation probes are
separate bounded intervals with collection stopped. Complete trial metadata,
including diagnostic failures and negative results, remain in the report.

## Results on this host

Median trial values below equally average the two real maps at each physical
pixel size. Main-thread and whole-process CPU measure different scopes.

| Emerald / Metal pixels | Main-thread CPU ms/frame, old → new | Change | Process CPU ms/frame, old → new | Change |
| --- | --- | --- | --- | --- |
| 1280×960 | 2.344 → 1.183 | −49.6% | 3.227 → 1.808 | −44.0% |
| 1920×1440 | 1.395 → 0.973 | −30.3% | 2.518 → 2.146 | −14.8% |

The controlled actual-source method comparison takes 90.664/83.084 μs per
old sample and 11.320/11.129 μs per reused sample: approximately **87% less
main-thread method CPU**. Allocation falls from about **74.3 KiB per call to
0–0.021 KiB** after warmup. Both new blocks execute zero full samples, while
each baseline block executes all 2,000. This isolates sample work; it does not
assign all end-to-end CPU changes to that method or establish gameplay FPS.
The first Emerald pair has slightly higher process CPU (+4.7%/+1.6%); the
other two improve. The medians do not imply that every individual run improves.
All accepted warmed Emerald scene intervals have zero full samples, zero
sample-cache misses and zero atlas-cache misses, with four retained samples.

FireRed creates no sample cache and runs zero full samples in both variants.
Its unchanged static path passes functional regression checks, but total
performance is mixed. Metal main-thread CPU changes from 1.458 to 1.677 ms at
1280×960 (+15.0%) and from 1.046 to 0.843 ms at 1920×1440 (−19.5%); process CPU
changes by +6.1% and −15.6%. Similar frame-interval wall times do not establish
CPU parity. Across three OpenGL pairs, median main-thread CPU changes from 3.558 to
3.797 ms (+6.7%) at 1280×960 and 5.490 to 7.409 ms (+34.9%) at 1920×1440;
process CPU changes by +6.9% and +34.4%. The third pair reverses direction
(process −0.5%/−6.0%), while the second pair is considerably worse. All values
are retained. A regression-free total CPU/performance claim is withheld;
these noisy end-to-end results remain an open performance control even though
the static sampler code path and its direct method cost are unchanged.

The complete [metadata report](qa/native-foundation/emerald-metal-cpu.json)
retains baseline profiling, the controlled method benchmark, every accepted
scene trial, the failed original OpenGL case, and a rejected same-process
scene pilot. The pilot's ordered NPC signature check fails because two dynamic
entry actors were appended in a different list order; its throughput is not
pooled with the accepted canonical-signature comparisons.

The real-ROM GPU oracle passes **37,358 assertions and 9,522,688 complete RGBA
pixel comparisons**, including **8,024,064 reflection-cover pixels**, across
both games on OpenGL and Metal. All 18 captures pass on their first attempt.
Emerald source phases/live floor, FireRed native tile frames, retained textures,
map return and FireRed indoor movement pass. Both ROM hashes are unchanged.
Final-source Metal window tests additionally pass **1,340 continuously checked
frames and eight own-window proofs**, with zero blank/stale frames or retries,
including movement, resize and map return.

A second independent oracle with `POKEPORT_NO_MODS=1` passes the same
**37,358 assertions / 9,522,688 RGBA comparisons** in all four game/backend
combinations, again with first-attempt captures and unchanged ROM hashes.
With mods disabled, the direct Emerald method control takes 87.768–94.453 μs
before and 10.815–11.130 μs after (about 88% less); allocation drops from about
90.3 KiB to 0–0.044 KiB per call. The analogous FireRed static-method AB/BA
control takes 12.480–12.649 μs before and 12.398–12.439 μs after, with zero full
samples in both variants. These method controls do not clear the whole-frame
FireRed performance limitation above.

Local ROM-free checks pass **105/105 engine suites, 3/3 SDK suites and B30**.
New sample-cache tests cover 1,018 comparisons/invalidation checks. The native
bridge lifetime test covers 12,000 presents and 100 window lookups. Six ownership,
six palette-profile and four cache-policy Python tests pass, along with Lua
parsing and whitespace checks. T3 content/link checks are skipped without an
import in the repository; real-ROM GPU acceptance uses separate instances.

## Scope and isolation

Only this independent fork clone and task-owned test instances are used.
Source exports and new fenced UUID identities load only assets/data and the
completion marker from earlier explicitly owned imports. No player saves,
options, external mods or player caches are loaded; legacy migration, identity changes and
external/portable roots are fenced before main. Only the test child's own
window is captured. ROM bytes, derived images/caches, local paths and process
or window IDs remain private.

The Origami port stays paused. Gen1 and the protected player instance remain
untouched. One non-dedicated host, short scripted scenes and a stationary
camera do not establish all-gameplay/fullscreen/context-loss/all-platform
performance. Native Metal window waits and worker scheduling remain measured
costs, and total process CPU must not be confused with the palette-method
improvement.

The longer FireRed/OpenGL regression exposed an inherited presenter failure:
repeated anonymous `ffi.cast` function-pointer declarations exhausted LuaJIT's
CType table (`table overflow`). The bridge now binds each Objective-C ABI once
when its native API is initialised. A regression test drives 12,000 presents
and 100 window lookups without further function-pointer casts; actual long
OpenGL runs and final-source Metal window checks cover the native integration.
The failed original baseline is retained. For the completed OpenGL comparison,
the presenter fix is applied equally to both palette variants. Metal timing
uses its GPU frame path, which does not call the OpenGL presenter; the sampler
source bytes are unchanged between the Metal measurements and final build.

The subsequent [FireRed OpenGL CPU investigation](firered-opengl-cpu.md)
addresses the avoidable native RGBA presentation cost left open here. It uses
exports without mods and an explicit no-mod flag, with the same pinned runtime
and a current-source baseline. Its scoped CPU and pixel/window results do not
replace the historical trials above or pool their different source conditions.
