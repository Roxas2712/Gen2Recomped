# Native field runtime adapters

Source fades observe the actual native script, warp, white-flash and battle
return states. Field fade requests share the extracted native FadeOverlay,
its fixed-step clock and whole-window veil. Sixteen palette steps and owned
holds do not replace native script timing or its abandoned-fade watchdog.
Unload cancels only the requesting owner's flow and continuation.

Source warp requests enter the existing native admission controller. Map
identities, bounds, input ownership, arrival bookkeeping and callback lifetime
remain native. The native transition retains its actual arrival kind while
active. Revoking a source continuation cannot rewind an admitted native warp.

Weather audio follows the existing native weather and frame clock, without
another weather simulation or gameplay RNG. `field.weather.sound` can claim a
weather playback request. Native weather uses a separate cached voice from
scripted/mod effects of the same sequence; removing the wrapper resumes native
weather on the next field tick. Missing imported sequences have no substitute.

`dataset.cache()` reads generated artifacts through the native cache filesystem
and current cartridge prefix. Readers retire on import, edition, root or session
replacement. This is read-only access to existing native files, not a second
importer, hydration path, alternate extraction layout or worker format.

Before actor admission, source pixel-position reads use the pending native
spawn in the current save. Movement and writes still require the real actor.
Ninety boot checks plus 261 player and 642 session checks pass on the refreshed
fork main (`e5687c08`).

The source START adapter opens/closes the real GBA menu and enters its native
input/draw phases once. Flow cancellation preserves unrelated overlays. Native row handlers are retained. Source content-template presentation and
callback lifetime attribution need additional integration.

Focused checks across FireRed, LeafGreen, Emerald, Ruby and Sapphire pass:
385 fade, 180 warp, 105 weather, 115 artifact-reader and 90 START-menu checks.
An API-2 loader/native-world fixture verifies source warps without requiring
another public API version. The original native warp suite also passes 206 checks.

On the earlier fork baseline, 485/485 engine suites, all three SDK suites and
B30 pass. The final-main regression is tracked separately. Metal and OpenGL each
pass 1,364 fade checks with 320 pixel comparisons/readbacks; RGBA8 comparisons
allow 1.51 channel quanta for factor quantization and final colour rounding.

Unchanged 1.0.9 initializes through the actual Metal/LOVE loader in all five
editions on synthetic imported data. This does not prove gameplay: the battle
card still reports a missing palette module, and native field/gameplay, complete
battle presentation and remaining UI contracts require further qualification.

QA uses disposable profiles, preserved frozen inputs and an 8 GiB reserve.
Player profiles, private runtime files and game assets are not included.

Native startup now keeps checked GBA header aliases on one physical definition.
A fresh ROM-backed FireRed run reproduced and resolved the former ambiguous
slot: the native bedroom now resolves as `FR_PLAYERS_HOUSE_2F` without weakening
the duplicate-slot rejection. Startup checks cover all five editions; the native
name lifecycle and retained Gen2 world/save-state regressions also pass.

Read-only warp forecasts reuse the native landing rules without invoking the
committing warp hook. Weather observations share the importer's enum and the
native cycle stage; editions without extracted cycle records use that same
native enum. Real preview admission and native Petalburg door-slide observations
retain their native clocks. Focused checks: 155 field observations, 70 previews,
75 door observations, 49 startup aliases and 486 collision regressions. General
cartridge door sheets and source-started door tasks remain unimplemented.

Source SE playback borrows an atomically identified native voice with its own
cache variant. Gain changes and owner cleanup cannot stop or attenuate another
playback; replay, unload and session replacement retire the borrow. 145 checks
cover these boundaries. Source updates do not advance a second audio clock.

The latest real Metal field capture shows a correctly oriented native fallback;
the paper renderer still encounters additional contracts during scene creation.
No full 3D, battle, UI or five-edition gameplay acceptance is claimed.

Healing sprite snapshots now reuse the native monitor/ball selection, borrowed
ROM artwork and cartridge offsets. Native drawing and mod snapshots share that
selection without stepping the task, sound or continuation. 125 checks cover
all five editions and the source anchor transform; real scene qualification
continues separately.

On the refreshed fork main, the current frozen runtime passes 572/572 engine
suites, Modkit 4/4, B30 and 916 companion checks. Resident animation-pair
observations retire with their real native atlas cohort and leave the native
clock unchanged. Legacy named RGBA animation banks remain a separate gap.

The ROM-backed field observation exposed a double canvas conversion: a producer
that already adapts clip Y for LÖVE 12 was adapted a second time. Complete
self-converting forwarding wrappers now retain their source. The asymmetric
GPU regression fails before the fix and passes 348 checks on both Metal and
OpenGL afterwards; 125 CPU shader and 151 compositor checks also pass.

`Renderer:frameRects()` exposes detached metrics from the same native viewport
calculation used by composition. Internal composition reuses private scratch;
callers cannot mutate it. A source field can render at actual drawable size
and supply its image directly, without a second scaling canvas. The unchanged
FireRed package now supplies a 1024x768 upright world for a 1024x768 test window.
121 checks cover resize, distinct DPI axes, native surfaces and composition.
Normal-camera flat interior artwork is the package's default, while its open
3D interior remains a separate option. This observation does not qualify that
option, other rooms, the battle card or complete gameplay (later camera observations follow below).

Missing native classes also cannot match ordinary mod screens through nil
metatables. Focused admission, field-move, transition, companion and battle
checks pass (55 / 316 / 308 / 916 / 382).

A real native step also exposed the optional companion in the ordinary source
NPC draw pool. Source followers have a separate presentation contract; their
native actor remains available to lookup and native update/draw lists, while
ordinary source NPC artwork excludes that actual native follower. Source-only
extension fields cannot disguise another NPC as a follower. The new regression
fails 25 assertions before correction and passes 90 checks afterwards. Object,
lifecycle, companion and native predicate regressions also pass. Complete
avatar/room presentation remains subject to the ongoing real-frame checks.

The source forced-terrain query now classifies existing semantic behaviors for
all five GBA editions, including Hoenn-specific IDs and FRLG spin arrows. It
does not construct a game or install a second movement controller. 1,367
classifier checks pass on both the current fork and composed API-2 baseline;
collision and player regressions pass as well. A real manager-driven open-3D
FireRed bedroom run now renders upright at 1024x768 with one visible player
and completes a native step. A later same-session run covers normal, open,
third and first in that bedroom without a runtime error. Normal and third
show one visible player; first hides its own sprite intentionally. The third
view completes a native cell arrival. Full room/gameplay acceptance is open.

`step_events.busy()` observes the native field admission after an arrival.
Native scripts, transitions and screens remain the owners; the adapter stores
no queue and cannot consume, flush or advance poison, hatch or repel counters.
617 checks cover all five editions, same-tick screen acquisition, retirement
and repeated reads, with 261 player and 642 session checks on the fork. The
composed public baseline passes the same 617 observations and 270 player
checks. Real first/third movement qualification continues separately.

START content rectangles now feed the native skin and source layout wrappers
from the same geometry. Native row keys retain dispatch while source entries
expose detached IDs/labels and the live Game3 facade. Unmodified menus retain
their original geometry; invalid/erroring layouts fall back to that rectangle.
The source window helper shares native cursor spacing and frame drawing.

Source glyph queries and single-glyph painting use the existing native
charmap, proportional faces and two-tone shader. Reloaded/relocated glyphs
are observed immediately; draw errors restore the native face and graphics
state. On both baselines, 226 layout, 90 menu and 115 glyph checks pass. The
real unchanged FireRed run 4c88811768 opens START, finds the original ASCENDANT
row, invokes its handler and captures the fully drawn original settings.
Its layout wrapper is attributed to ORIGAMI_ASCENDANT. This does not qualify
every settings action, other editions or the still-unavailable battle card.

Owned actor presentations now survive collection of temporary source views,
including an explicitly absent renderer. Native actor removal, cohort changes
and owner teardown retire them through the existing service. Foreign teardown
cannot clear another owner's renderer. The old weak-value binding fails 35
GC assertions; the corrected ownership passes 60 checks on both baselines.

A wrapped source follower also begins as an unpainted logical actor after its
one native update. Imports and ordinary reads preserve native artwork, and an
existing owned renderer keeps its owner. This initial admission closes a second
gap: consumers may cache nil and never make an explicit sprite assignment.
85 admission checks pass on both baselines, with 90 pool, 916 companion, 20
object-lifecycle and 3,238 native predicate checks on the fork. The retained
Sapphire normal-view counterexample shows two avatars before correction; the
47c240dd72 run shows one after forced GC, while the native follower remains
admitted with an explicitly absent source renderer. All five actual starting
rooms have now reached normal/open/third/first views; native 2D passthrough
remains intentional for Hoenn's normal setting. This is still starting-room
coverage, not full playthrough or cartridge-feature discovery acceptance.
