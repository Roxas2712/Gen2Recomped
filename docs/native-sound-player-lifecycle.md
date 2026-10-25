# Native M4A sound-player lifecycle — development checkpoint

This branch extends Gen2Recomped #270. Native M4A effects now replace the
preceding source on their imported player, independently of the sound ID,
named role, pan or mono cache key. Other players keep their sources. A cached
PCM used by another player receives a separately cached voice instead of
rewinding the original. Those voices remain in the normal volume, invalidation
and device-lifecycle paths.

The native `playId`, `playSe` and named-role entrypoints share ownership.
Explicit native queries and stops observe every owned voice; stop-by-ID also
reaches multiple players using the same ID. Emerald's regular query excludes
its special player three, while an explicit-ID query includes it. File/string
and disabled overrides bypass native replacement, following the unchanged
reference's separate override path. Legacy sound dispatch remains separate.

The original 20 paired cases had 16 differences; all four workers exited zero.
Those complete negative observations remain retained. Expanded controller
inputs now cover 40 paired cases including named/native entrypoints, clones,
stop-one/all, per-player queries, special-player policy and file/string/disabled
overrides. The first 36-case extension and existing Poison/Focus Band and PCM
contracts are equal; the final expanded frozen rerun is pending at this commit.

Actual-host regression passes **110 checks**, including volume on every cached
voice, invalidation, generic named queries/stops, suspend/resume, failure while
building a replacement and legacy overlap. The first test's floating-point
volume assertion failed on operation order; its raw report remains retained,
and the corrected check measures both voices within 1e-12.

Native command revision **18** rejects revision 17 before battle setup; party
codec remains 1. An independent frozen-parent serializer changing only 17 -> 18
matches native digest `c82a14f754706103`; legacy digest remains
`e33d251961f2a41d`. The protocol suite passes **154 checks**.

The speaker double runs unchanged reference audio and actual host M4A sources.
It retains stopped hardware objects across native `stopSe`, so reuse remains
observable. The first incomplete-inventory fixture is retained as a failure.
The active-output comparison records command ownership with no playback-time
advance; it is not a claim of full synthesizer waveform or public-event timing
parity. No reference function is replaced, no normal cache/save is written and
no game, GPU or audio device is launched.

Full regression, complete existing command comparisons, actual-import and
combined-fork qualification remain required before PR publication and playable
branch integration. Earlier successes, negative controls and superseded
fixtures remain in `tmp/native-sound-lifecycle-qa/`.

```sh
nice -n 19 python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/reference --lua /path/to/pinned/luajit \
  --mode native_sound_lifecycle --mode native_sound_pan \
  --mode battle_effect_presentation --report /path/to/new-report.json
```
