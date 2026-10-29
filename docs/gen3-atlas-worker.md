# Gen-3 source atlas worker

`Performance.atlasWorker` prepares copied Gen-3 source atlas banks in the
existing build pool. `AtlasPixelsCore.run` returns detached RGBA and index
streams plus the initial CPU state. `AtlasPixels.fromCore` restores the
main-thread model without repeating metatile compositing. The live decoder
retains the original bank and animation frame-table references; palette
cycles, palette overrides, edits and uploads retain their existing owners.

The worker path is limited to plain channel-safe data and unchanged native
constructors/decoder methods. Plain mod data edits are copied and validated
again before publication. Functions, metatables, unsupported data, changed
source values, failed workers, retirement and context-loss timeouts retain
the existing coroutine path. Public pending jobs remain typed coroutine jobs;
no pending placeholder enters the resident atlas table. LOW admits two atlas
jobs to the pool's one worker. A five-second timeout bounds lost replies.

IdleStream's central poll accepts completed CPU data without allocating graphics
resources. The existing stream owner then uploads at most one texture per step,
and publishes only after both textures are complete and the captured source
values are still current. Source edits, replaced public coroutines or disabled
workers retire unpublished resources and retain the native coroutine fallback.
A required `get` uses a zero-wait timeout: it cancels pending CPU work and uses
already accepted current pixels or the existing constructor, preserving immediate
admission without running unrelated callbacks or adding a 50-ms frame stall.
Textures and resource leases retain their normal publication and retirement.

The ordinary native Gen-3 renderer has a different atlas producer. This
switch targets the source field/atlas bridge; a vanilla scene that never
uses it cannot establish a worker speedup. `check_performance_baseline.py
--atlas-bridge` installs a pass-through source-field callback in its owned QA
host, enters the production replacement boundary with the native game/map/
actors/clock and records actual adapter draws and worker cache provenance.
No alternate simulation or shipping callback is installed. OFF and ON use
the same source and bridge scene. The initial `a474e83b` comparison below,
including main `9d8eec4c`, did not qualify a merge. The subsequent complete
ABBA comparison on `3b06b0bf`, including main `dc691d626`, satisfies the
pre-registered performance gate. See the [current qualification](qa/gen3-atlas-worker-qualified-2026-10-29.md)
for all four cases, exact scope and validation; it establishes an atlas
main-thread preparation benefit, not a general game FPS or energy claim.

`luajit tools/atlas_worker_check.lua` checks all five GBA editions, exact RGBA
and index streams, live animations and palette edits, reference ownership,
late replies, source changes, cancellation, failure and the independent
switches. The actual graphics-free worker host additionally transports the
production core through LÖVE threads and compares its bytes on LOW.

## Seam control, 27 October 2026

Each fresh Emerald import uses the production source-field adapter in its
owned QA host on M2 / 16 GiB / LÖVE 12 Metal, 1024×768 logical / 2048×1536
framebuffer, fixed HIGH, cap 160, VSync off and background cap disabled.
Both source-stable cases run for at least 60 seconds. Actual native movement
covers 33 cells Route 101 → Oldale and 20 cells Oldale → Route 103.

| Worker | Average frame, ms | Route 101 → Oldale maximum, ms | Oldale → Route 103 maximum, ms |
| --- | ---: | ---: | ---: |
| Off | 8.488980 | 191.980625 | 147.404000 |
| On | 8.532692 | 195.724500 | 151.738125 |

The OFF cache changes from one to two native atlases. ON submits two jobs:
the initially required atlas cancels and builds synchronously; one prefetched
atlas publishes during measurement. The final cache holds one native and one
worker atlas. Both cases actually draw through the bridge (7249 / 7214 total
observed calls), so the comparison does exercise the intended producer.

No gain is demonstrated. The OFF trace is unfocused throughout; ON starts
focused, becomes unfocused at 42.53 seconds and focused again at 58.54 seconds.
HIGH and the cap policy remain fixed, but the differing focus states preclude
a causal performance conclusion. These instrumented native-host observations
are not interactive FPS acceptance. No other QA from this task ran during the
measurements. The complete pair is retained; no winner is selected or rollout
policy changed from it. Mobile/context-loss hardware and energy are not measured.

The first complete qualification at `050bdd24` passes 173 stages, including
all native suites, the switch matrix, API3/fixtures, real LÖVE 11.5 transport
and Metal rendering. The actual LOW worker compares 327,680 RGBA bytes over
all five GBA editions with zero difference and no graphics module in its VM
(987 dynamic checks). The coroutine-ownership revision passes eight focused
integration stages, including 845 assertions. Subsequent private admission
guards cover replacement source modules and immediate custom-provider replies;
they do not change the pixel factory or decoded output and have their own
focused checks (849 assertions and five integration stages, all passing). The timing source predates those guards.

[Raw qualification and measurements](qa/gen3-atlas-worker-2026-10-27/qualification.json)
are retained alongside `coroutine-ownership.json`, `seam-off.json` and `seam-on.json`.

## Historische Zwischenstände und qualifizierter Abschluss

Die [Prüfung vom 28. Oktober](qa/gen3-atlas-worker-review-2026-10-28.md) und der
[zunächst blockierte Folgestand vom 29. Oktober](qa/gen3-atlas-worker-review-2026-10-29.md)
bleiben als getrennte Zwischenstände erhalten. Ihre abgewiesenen Fokusläufe
und abgebrochenen Tests begründen keinen Leistungsnachweis.

Der [abschließende gleiche Aus–An–An–Aus-Vergleich](qa/gen3-atlas-worker-qualified-2026-10-29.md)
besteht dagegen alle vorab festgelegten Kriterien: 56,34 beziehungsweise
70,32 Prozent weniger gemessene Hauptthread-Zeit für die Atlasdienste, höchstens
0,33 Prozent Änderung der mittleren Framezeit und keine Verschlechterung der
gemittelten Nahtmaxima. Der gleiche Quellkopf besteht 956/956 Engine-Suites,
SDK 4/4, alle verfügbaren ROM-freien Tiers sowie die echten Grafikprüfungen.
Die unveränderte Qualität, Besitzer- und Fallback-Grenzen sind im Nachweis erfasst.
