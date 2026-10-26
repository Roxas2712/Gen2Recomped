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

The source START adapter opens/closes the real GBA menu and enters its native
input/draw phases once. Flow cancellation preserves unrelated overlays. Custom
row callbacks and content-template presentation need additional integration.

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

## Public-host composition

This API-2 offer builds on #328/#327 and their declared native map, player,
session, modal-stack and rendering prerequisites. The existing native warp
admission helper is reused internally; it does not advertise another public
API version. The composed API-2 candidate passes all five focused suites,
916 companion, 1,466 terrain, 486 collision and nine lifecycle checks plus
all three SDK suites. Engine results are 100/111 versus 95/106 in the frozen
reference, with the identical eleven inherited failed suites.

The unchanged-package loading result above belongs to the fork; it is not a
claim that this standalone public branch accepts or fully runs that package.

Additional source observations reuse native ownership: checked cartridge map
aliases share one physical definition, warp forecasts avoid committing a warp,
weather follows the native importer enum and cycle, and previews observe actual
native admission. Door observations currently cover the native Petalburg slide,
not general source-started door tasks. Healing snapshots and native drawing
share the same borrowed ROM-art selection and offsets.

Source audio borrows a distinct cached playback and retires with that playback,
owner or session. It cannot change another owner's gain or stop its voice.
Unloaded native UI/field classes cannot admit ordinary mod screens through nil
metatables. Resident animation observations build on the separate atlas offer;
they do not implement named RGBA animation banks.

Detached `Renderer:frameRects()` metrics share the native compositor's viewport
calculation. Source field producers can request the real drawable resolution
and pass an existing canvas directly to the scaling compositor. Private native
scratch is reused and is not exposed to callers. Shader conversion is handled
by the separate orientation offer #193. Complete mod, battle, door and UI
presentation acceptance remains open.


The indexed-palette adapter now reuses a factored native shader factory with separate native-background and source banks. Native backdrops retain their continuous texture alpha and replace sixteen individual palette uploads with one array upload. Source RGB555 arithmetic, blending, affine/gray resolution and a real cutout shader share this implementation; owner teardown cannot release the native bank. This does not implement animation-pack adoption, another animation VM, or the complete battle presentation protocol.

The fork and composed public baseline each pass 7,771 palette checks and 382 native animation checks; battle admission passes 382 on the fork and 397 on the older public baseline. Metal and OpenGL each pass 1,168 RGBA8 GPU comparisons. The deliberately shared-bank Metal counterexample fails at the intended nested native/source palette comparison. A corrected raw-output measurement uses premultiplied replacement blending; the earlier alpha-multiplying measurement failure is preserved. A new unchanged FireRed run reaches the field and START → ASCENDANT with no loader errors; the battle card now reports the next missing contract, `Ui.takeCommand`, and remains unavailable. None of these checks qualifies full unchanged-mod gameplay.


Native source move commands are borrowed at the existing selection commit boundary and taken once. Changed slots/targets re-enter native selection and refusal handling; actual source PP transactions are flushed before validation. Covered, replaced or retired admissions cannot commit stale choices. Ordinary/native-only paths and other native controller-owned action classes keep their owners. Live cursor writes update validated native indices instead of shadowing them, and UI busy/dialog observations read the actual native queue. This command interception currently covers move choices; the remaining command classes and complete presentation protocol are not claimed.

Both baselines pass 390 command/cursor/observation checks, including doubles, changed targets, cancellation, PP refusal, exceptions, native callback ownership and multiple/nil native return values. The fork retains 382 admission and 382 animation checks; the public composition retains 397 admission and 382 animation checks. Its refreshed full engine result is 127/138 with exactly the same eleven inherited failed suites as the preserved reference; Modkit 3/3 passes. The older public input bodies were factored into shared selectors without changing their normalized source bodies or backporting newer battle rules. Unchanged FireRed high/ultra field runs still load with no loader errors; the battle renderer now reaches its next missing contract, `src.core.game3.display`. The original high-quality FXAA card is active and available on the real Metal run; initial pre-preset health snapshots were stale. Ultra supersampling remains a separate optional setting and is being qualified independently.


Real unchanged FireRed quality observations now cover Metal and OpenGL: High runs its active FXAA card at 1024x768, while Ultra with the separate supersampling switch enabled renders and returns a 1536x1152 world for that window. The native compositor scales it once and retains upright native UI. A separate real Retina Metal run reports a 2048x1536 drawable for 1024x768 logical units and an upright 3072x2304 Ultra world. These are starting-room render/capture observations, not full gameplay or performance benchmarks. The original mod deliberately bounds field resolution when its optional supersampling setting is off; its own quality policy is preserved.
