# Native Gen2 radio music and Snorlax admission

The native tuner and wall-radio script now start the imported channel song
through `src.core.Music`. Retuning starts the new station once; advancing
text or drawing never restarts it. Leaving the card or removing its screen
transfers the actual playing song to the native map owner, so battle music
can restore it. A new map replaces that override normally. Unavailable or
failed channel audio produces silence and restores map music on exit; it
cannot accidentally leave a previously selected flute song active.

The EXPN Card still controls availability of the flute station. The native
`SnorlaxAwake` special now checks actual flute playback and the player's
local map cell against the five cartridge proximity cells. Owning EXPN,
stale `g2RadioChannel`/`g2MapMusic` fields and rendering coordinates cannot
substitute for those conditions. A music selection hook replacing the flute
is respected and does not manufacture flute admission.

`tests/engine/gen2_radio_audio.lua` exercises actual Music with a fake audio
device, native Pokegear input/StateStack and compiled Gen2 scripts through
ScriptRunner: 167 checks across Gold, Silver and Crystal. It covers all five
cells, wrong-cell refusal, real wall-radio suspension/return, retuning,
failed audio, close, battle restoration, map replacement, external music
ownership, mod-selected audio and generation isolation.

Diagnostic exact source `9f2b6f4d` passes four-platform runtime qualification
40249447920. Actual Crystal and the unchanged full supplied Johto package pass
71 checks per OpenGL/Metal backend, both selected field cameras, with twelve
OS-window images inspected. Real device Sources play the imported flute; an
independent half-second decode is non-silent. The actual imported Snorlax
operand returns correctly at the adjacent/wrong cells, after close and after
map change. Setup explicitly stages introduction, maps, EXPN and radio card.
Metal warning overlays remain. See the sanitized
[receipt](qa/native-foundation/johto-native-radio-audio.json).

Composed `d1bd32eb` passes424/424 engine suites, SDK3/3 and all quick tiers.
Qualification40251541022 attempt2 passes all four platforms and packaging.
Fresh actual Crystal/unchanged Johto GPU checks pass71 per backend and all
12 OS-window images were individually inspected; see the separate
[composed receipt](qa/native-foundation/johto-native-radio-audio-composed.json).
The first Intel attempt failed fetching its host through a transient DNS
error; its engine checks passed and the same-source retry completed.
Main subsequently gained native frame pacing, so this remains a diagnostic
source. The newer composition needs its own runtime/GPU acceptance before
publication. The existing preview still ships presentation source4be92945.

This change covers station entry/exit and the native story gate. Complete
ROM-driven show text, timing, schedules, intermediate jingles and music-show
choices are still open. Device-free tests do not establish audible hardware
playback, original story-trigger admission, unchanged-mod GPU acceptance or
a complete playthrough. Exact-source runtime/GPU qualification is required
before inclusion in the existing preview.

Original implementation by Roxas2712; existing upstream/third-party credits
and licenses remain applicable. See `NOTICE.md` and
`LICENSE-ROXAS2712.md`.
