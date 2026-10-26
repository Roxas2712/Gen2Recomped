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
