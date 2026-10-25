# Native GBA battle-effect presentation work in progress

This branch extends native Substitute art at `bff8ec57`. It is development
work, not an accepted PR or a replacement for the playable testing branch.
Gen1 remains read-only at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

## Implemented native Poison path

Successful native poison status changes queue their status-animation command.
The actual battle queue executes the native shake, two palette cycles and six
edition-specific sounds. Presentation does not change HP, status, PP or battle
RNG. Hidden/protected actors and disabled animations follow native skip rules.
Mono/stereo uses the existing game sound option. Live sprite offsets and tint
reach the battle renderer through its normal presentation methods.

Native numbered sounds also resolve through cartridge songs when no named
role exists. Explicit panorama and mono controls preserve the original mix;
each control combination owns a separate cached source. Existing named-role,
native-name file/string overrides and disabled sounds retain their behavior.
Cache invalidation refreshes the native number lookup after a mod audio edit.

## Evidence

- Unchanged native sequencer/VM versus actual host queue: **144 paired Poison
  inputs / 1,848 ticks / 144 actual sound controls**, all equal. Inputs cover
  all six single/double positions, animation options, stereo/mono and native
  hidden/Substitute skips. Every actor's captured display state, HP, status,
  protection, and RNG count participates in comparison.
- A common owned PCM carrier runs through the native mixer and host pan
  processor: **56 paired cases**, all samples and format metadata equal.
  The initially mismatched 32768-Hz carrier fixture is retained; the qualified
  fixture uses the native default 44100-Hz input, without rewriting results.
- Actual host M4A sequencing, source creation and dispatch: **165,455 checks**,
  including source separation/reuse, all PCM samples, mono, retained defaults,
  file/string overrides, silence and legacy forwarding. Existing mod audio:
  **116/116**. Native status presentation unit checks: **3,074/3,074**.
- The broader complete command regression retains **11,520 multi-hit rows**,
  **1,920 Mirror Move rows** and **360 Substitute-controller cases**. The 192
  poison-command differences are resolved. The complete comparison remains
  **failed** on **1,152 animation observations**, all Substitute fade or
  Focus Band. No observation, event, RNG field or animation was removed.

Audio controls are measured at the output source. The Source carrier uses
owned cached PCM; the host carrier runs through its actual M4A sequencer.
The separate mixer comparison covers the same input samples on both engines.
This does not establish whole-synthesizer waveform equality, all public audio
event parity, or final scene pixel equality. CPU hardware doubles launch no
game, audio device or GPU preview and modify no normal cache/save.

## Remaining gates

Implement and qualify actual Substitute-fade and Focus Band playback, not
ignored animation rows. Retain the failed broader matrix until every captured
field agrees. Full regression for this runtime, native command revision/link
compatibility review, broader Mirror Move history, real linked roles and actual
public-submission scenarios also remain required before publication or stable
testing-branch integration.

Raw successes, failed/superseded inputs and complete observations remain in
`tmp/battle-effect-qa/`. Reproduce the focused contracts with:

```sh
nice -n 19 python3 tools/enemy-action-contract-check/check.py \
  --gen1 /path/to/clean/reference --lua /path/to/pinned/luajit \
  --mode battle_effect_presentation --mode native_sound_pan \
  --report /path/to/new-report.json
```
