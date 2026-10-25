# Native world-script sound waits — reproduction checkpoint

Gen2Recomped currently lowers native GBA `waitse` to no operation. A script
therefore reaches its following variable write while native sounds are still
playing. The unchanged Gen1Recomp native VM waits until its current SE players
finish, with the profile's special-player policy.

The paired owned script uses the actual native VM and the actual host
Gen3ScriptVM/ScriptRunner for `waitse; setvar; end`. Audio is started through
real engine entrypoints before the script starts, isolating wait behavior from
sound-command lowering. Speaker hardware and sound data are owned; no engine
function is replaced and no game, device, normal cache or normal save is used.

At frozen commit `aaf44f4eed3bb49a910b8a77d11e73c2075d8396`, all four workers
exit zero. **Seven of twelve complete paired cases differ**. Source/host
active voices and native queries remain identical at every recorded frame;
the difference is premature script completion and its post-wait variable write.
FireRed waits for players one, two and three; Emerald's ordinary query excludes
player three. Both engines complete immediately for silence and file-only
overrides. Native sound plus a file override must still wait for the native
sound. The full negative observations remain retained, with a source-bound
[negative receipt](qa/native-sound-script-waits-negative.json).

No runtime fix is included at this checkpoint. Before implementation, the
native polling fallback and Audio.update callback clock must be qualified as
well, including current-player replacement, stops, suspension and return to
gameplay. The frozen player-ownership change on
`feature/native-sound-player-lifecycle` remains separate.

The unchanged reference's [clock oracle](qa/native-sound-script-wait-clocks.json)
now qualifies ten actual-controller cases across the two profiles. With no
audio ticks, the native polling fallback completes at logic tick **181**. One
post-logic audio tick per logic step completes at **180**; two complete at
**90**. One audio tick per two logic steps reaches the **181** polling fallback.
These clocks cannot be collapsed into a single fixed delay.

The native callback also latches silence: if Audio.update observes silence and
a replacement starts before the next VM tick, the script still resumes at
tick **2**, with the replacement sound playing. Polling only the current sound
would miss this behavior. The implementation must preserve both the callback
clock and native polling fallback, including that latched completion.

To reproduce those source-only controller cases, run from the pinned clean
reference checkout:

```sh
nice -n 19 /path/to/pinned/luajit \
  /path/to/host/tools/enemy-action-contract-check/native-sound-wait-clock-oracle.lua \
  /path/to/host
```

```sh
nice -n 19 python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/reference --lua /path/to/pinned/luajit \
  --mode native_sound_script_waits --report /path/to/new-negative-report.json
```

Reference: `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, read only. LuaJIT:
`a4c064539ea931274d407e1249b4bb575424a0f4`. Exit one is the expected aggregate
negative result; no worker crashes or discarded observations are accepted.
