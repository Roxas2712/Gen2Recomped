# Native sound-player lifecycle — reproduced gap

This development checkpoint adds a paired negative control, not a runtime fix
or an accepted PR. It extends the Mirror/presentation foundation at `a215dc3d`.
The existing qualified integration candidate remains separate.

Unchanged native `Audio.playSe` replaces the preceding source on the selected
M4A player, including a different sound ID or a cached pan/mono variant. It
retains sources on other players. The current host cache restarts only the
selected cache key, so sources on the same native player can overlap.

Twelve paired cases cover both FireRed and Emerald. All four workers exit zero
and preserve their full play traces and every active-output snapshot. Eight
cases differ: different IDs on one player, pan changes, mono changes and
replacement of one player while another remains active. Ordinary retriggering
and independent-player overlap already agree.

The speaker double observes actual unchanged native audio and actual host M4A
sources. It retains cached hardware objects across `stopSe`, so native source
reuse remains visible. The first incomplete-inventory fixture and its raw
report remain retained separately. No reference function is replaced and no
normal cache, save or audio device is opened.

The existing importer already records the native `player` field from each
eight-byte song-table entry. A follow-up runtime fix must preserve named roles,
file/string/disabled overrides, independent players, source reuse, cleanup,
suspension and legacy behavior. Public sound-event timing and synthesizer
waveform parity are separate unqualified surfaces. Raw evidence is retained in
`tmp/native-sound-lifecycle-qa/complete-inventory-negative.json`.

```sh
nice -n 19 python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/reference --lua /path/to/pinned/luajit \
  --mode native_sound_lifecycle --report /path/to/new-report.json
```
