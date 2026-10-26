# Native GBA cry playback and world-script waits

The admitted FireRed/Emerald profiles use the native species recording,
cry mode, integer release envelope, pitch, chorus and reverse controls.
`playmoncry` resolves both species and mode through the script variable
store and starts playback immediately. `waitmoncry` yields the actual
runner until the tracked cry finishes. Generic GB `play_cry` retains its
existing text-dialog behavior.

The cry clock runs with the real 60 Hz audio service. A waiting script
advances it only if no audio tick occurred since its previous poll.
Recording-derived duration wins over a stuck audio source; early source
completion also releases the wait. Missing native audio data retains the
native 64-frame fallback. SE-player ownership and waits stay independent.

Native WaveData supports ordinary signed PCM and Game Freak DPCM. The
renderer applies the native modes at the GBA frame rate, including Emerald's
mode-six volume. Native Hoenn cry IDs follow their species control table,
not the species position after the old Unown slots. New imports advertise
`gen3Cries.mapping = "native-species-v1"`; existing stock sequential Hoenn
entries are corrected during native playback. Explicit mod-owned, file,
string and disabled definitions retain their override path.

Rendered PCM is cached in a bounded per-data cache. Each playback owns a
fresh source, preserving overlapping cries. `stopCry` stops the latest
tracked native source. Species invalidation and session suspension release
associated sources. Isolated dex playback uses native PCM without replacing
the world's wait state, controls or music attenuation.

Native command revision **19** prevents lockstep with revision 18's cry
semantics. Party codec revision remains **1**. Independent frozen-parent
serialization changes only command revision 18 to 19: native fixture digest
`22e453523676534e`; legacy digest `e33d251961f2a41d` remains unchanged.

## Development validation

The initial targeted checkpoint passes 10,983 engine checks, including real
Game/FixedStep/StateStack clocks at 1x/2x/10x, field locks, public command
hooks and script-ended events, isolated playback, cache/source ownership,
missing devices, device recovery and the real structural cry importer over
owned bytes. Existing protocol, SE-player lifecycle and world-SE-wait suites
also pass (175, 110 and 6,306 checks).

Three cross-engine contracts execute unchanged Gen1 code at
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`: native cry commands, lifecycle
and complete PCM/decoder observations. Twelve successful workers compare
554 complete paired observations on FireRed/Emerald, independently rechecked
with JSON boolean types preserved. No reference function is replaced.
Hardware doubles implement SoundData and source output; no game, GPU or
actual audio device is started. The test filesystem is isolated.

Reproduction:

```sh
LUA=/path/to/pinned/luajit bash scripts/test.sh --quick
python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/gen1-reference --gen2 . \
  --lua /path/to/pinned/luajit \
  --mode native_cry_commands --mode native_cry_lifecycle --mode native_cry_pcm \
  --report /path/to/cry-contracts.json
```

Use LuaJIT `a4c064539ea931274d407e1249b4bb575424a0f4`. Full fresh-baseline,
combined-fork regression, complete command matrix, negative audio-clock
control and final existing-import qualification remain required before the
PR and playable testing branch are published. These targeted results do not
prove every audio event, unsupported native profile, full mod or playthrough.
