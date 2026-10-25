# Native GBA Focus Band presentation — development checkpoint

This branch extends `816346bc` and queues the native Focus Band general
animation before the held-on message in both native damage paths. The real
battle queue owns its frame clock, sound, red palette fades and signed
fixed-point movement. Animation options retain the native general-animation
pause. Visible Substitute and hidden actors skip playback; a temporarily
lowered Substitute permits playback without changing its logical HP.

The complete native sequencer/VM comparison currently matches **384 paired
inputs / 11,112 tick states / 192 sound controls** across FireRed and Emerald.
It covers Poison and Focus Band, all six single/double actor positions,
animation options, mono/stereo, ordinary, hidden, Substitute and lowered
Substitute states. The expanded host unit covers **13,778 checks**.

The first controller and incomplete Emerald fixture failures are retained in
`tmp/focus-band-qa/`. Emerald requires native picture coordinates to execute
its return task. The owned test dataset supplies those coordinates through
the existing virtual cache filesystem; no reference functions or files are
patched. The comparison checker now rejects native VM error/wait-cap
diagnostics even if the worker exits zero, and fingerprints the sound fixture.

The frozen runtime full run completes **161/170 engine suites**, SDK **3/3**
and B30. Its exact anchored FAIL-line Counter equals fresh #258: the same
**25 lines / nine inherited suites**, with no additions or removals.

The complete damage-command matrix resolves all **576 Focus Band animation
differences**; its remaining **576 Substitute-fade differences** are retained.
The first frozen run also rejects an erroneous FireRed fixture assertion:
FireRed's native built-in back offset is 10, while the owned Emerald input is
8. The assertion now checks each edition's actual input; runtime code is
unchanged. A source-bound focused rerun is required after this fixture fix.

The reference remains read-only at
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. Substitute fade,
broader Mirror Move/link/public-submit gates
and native command revision review remain prerequisites for final acceptance.
There is no claim of final GPU pixel or complete synthesizer waveform parity.
No PR or playable-branch update has been made for this checkpoint.
