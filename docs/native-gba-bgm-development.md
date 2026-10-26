# Native GBA background music: development checkpoint

This work continues the native-audio series after #289. It is an incomplete
development checkpoint, not a release qualification or a claim of complete
music parity. The playable integration branch has not been advanced.

The world VM preserves `playbgm`, `savebgm`, `fadedefaultbgm`, `fadenewbgm`,
`fadeoutbgm` and `fadeinbgm` as native commands. Logical current, map and
saved music remain independent of physical song labels. Only `playbgm`'s
keep flag `1` or `true` saves an override; zero and `0xFFFF` stop playback.
The actual native world adapters use fixed speed four for outgoing and
incoming fades, regardless of the encoded speed. `fadenewbgm` dispatches
immediate playback in those adapters.

The admitted FireRed/Emerald identifier catalogue includes 305 `MUS_*`
names, including aliases and native reverse names. Named mod file music
can be selected by numeric native commands without renaming its definitions.
Shared mod music retains its own transport and user-volume behavior.

Emerald's default selection reads live map identity, player position,
saved weather and story variables/flags through the host's existing formats:
`MAP_Gxx_Nxx`, `save.gen3Vars`, `save.flags` and `save.gen3Weather`.
It handles Route 111's sandstorm, Sootopolis silence, legendary weather,
the occupied Space Center and Weather Institute, and Route 118's split at
x=24. Repeated commands re-read the current state. FireRed retains its
separate map-song default. This does not yet replace every map/bike/surf
transition entry point.

## Checked at this checkpoint

All comparisons run unchanged native Gen1 code at
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, using the real production world
adapters, VMs, music services and owned audio hardware doubles. No native
audio method is replaced with a host result. LuaJIT is pinned to
`a4c064539ea931274d407e1249b4bb575424a0f4`.

- **24 workers / 2,524 complete paired observations**, independently
  compared with JSON booleans distinguished from numeric zero/one.
- The new BGM contracts contribute **1,970 rows**: 1,844 symbol rows,
  32 command/lifecycle cases with all 81 frames and play traces per case,
  and 94 default-policy cases with all five frames and play traces.
  File cases retain every created source, including stopped sources and
  their actual gains. The remaining 554 rows recheck native cry contracts.
- **80/80** BGM engine checks pass. The full feature quick run passes
  **168/177** engine suites, SDK **3/3** and B30. A fresh #289 parent run
  passes **167/176**; the exact anchored `FAIL ` line Counters are identical:
  **25 lines / nine inherited failing suites**, with no additions/removals.
- The changed workflow passes actionlint. New modules and BGM test files
  pass StyLua verification. These are local results, not executed hosted CI.

The earlier development default-policy probe reproduced differences in
44/88 Emerald cases and none of the six FireRed controls. Failed and
superseded reports remain retained. The corrected implementation passes
all 94 cases, including live state changes after an earlier default command.

## Work still required before a pull request

- Real native M4A producer startup and queue lifecycle. An actual sequencer
  probe with owned music bytes reproduces the startup difference on both
  profiles: the native source starts at the following audio tick, while the
  host currently starts during cue construction. Full raw PCM buffers and
  source observations are retained; file-only agreement does not prove
  native-stream equivalence or whole-synth waveform parity.
- Native versus mod music ownership across source reuse, no-output and
  failure paths, plus native fanfare/deferred/default transitions.
- Public music hook/event timing and context, actual-import regressions,
  the complete existing contract matrix and a qualified combined runtime.
- Native command revision and an independent frozen-parent serializer
  audit before compatibility claims or advancing the playable branch.

Tests start no game, GPU or audio device and write no normal saves/imports.
No ROM, generated recording or private import is committed. This checkpoint
does not establish arbitrary full-mod compatibility or a completed playthrough.

## Reproduction

From this checkout, with the pinned LuaJIT and a clean read-only reference:

```sh
nice -n 19 env LUA=/path/to/pinned/luajit bash scripts/test.sh --quick
nice -n 19 python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/gen1-reference --gen2 . \
  --lua /path/to/pinned/luajit \
  --mode native_bgm_symbols --mode native_bgm_commands --mode native_bgm_policy \
  --mode native_cry_commands --mode native_cry_lifecycle --mode native_cry_pcm \
  --report /path/to/bgm-development-report.json
```

Keep every raw worker and failed report. The canonical checker records the
complete observations; checkpoint qualification additionally performs an
independent recursive comparison that distinguishes JSON boolean types.
