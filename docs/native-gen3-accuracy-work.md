# Native GBA accuracy work in progress

This development branch starts at PR #214 (`440a5da6`). It is not yet a pull
request and is not included in the green `codex/portability-testing` branch.
The clean read-only Gen1 reference remains
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

Implemented: the private `Gen3Accuracy` command uses native percentage draws,
the combined accuracy/evasion stage ladder, ordered ability/item floors,
Foresight, all-active-battler weather suppression, Protect/semi-invulnerability,
Oak's separate damage/stat flags and Teachy-TV guarantees. The public
`battle.accuracy` boundary carries native move IDs and the calculated accuracy.
As in the reference, the threshold is steerable; replacing the context's `rng`
field does not replace the live battle stream. Absorb abilities are resolved
before damage computation and do not print a generic miss message. Older
cartridges keep the existing byte path.

The actual reference `Engine.newContext(...):accuracyCheck` is compared with
`BattleState:accuracyRoll`. A second matrix executes the real move resolver on
both engines with a shared public critical hook returning false, to isolate
accuracy/secondary ordering from the already-tested critical command. It keeps
all bounded RNG calls and values, public accuracy contexts, damage-callback
counts, PP, target HP, stat stages and Flash Fire state. No observation is
removed or rewritten to hide mismatches.

Current local evidence (maintained LuaJIT pin
`a4c064539ea931274d407e1249b4bb575424a0f4`):

- 15,082 focused assertions pass on FireRed/Emerald profiles. The complete
  accuracy-command observation matrices match exactly.
- Full ROM-free run: 96/105 engine suites, SDK 3/3 and B30. The exact Counter of
  the 25 inherited FAIL lines across nine suites matches clean #214 (95/104).
- Strict shared checker: 64 worker runs / 12,314 paired observations, **not
  fully passing**. All prior modes and both new accuracy-command comparisons
  pass. The execution matrix retains 56 different Thunder cases per profile:
  the reference's post-hit secondary roll is `0..99`; the legacy host handler
  uses `0..255`. The accuracy thresholds, accuracy draw boundaries and other
  observed ordinary cases agree. The raw mismatch report is retained in
  `tmp/native-accuracy-qa/retained-execution-gaps.json`; the complete report is
  `tmp/native-accuracy-qa/contracts-first.json`. These are ignored private QA
  outputs, not distributed cartridge data.

Before publishing or integrating this branch, implement and independently test
the shared native post-hit secondary-chance path, including explicit zero
chance, Serene Grace, Shield Dust, Substitute and status/type guards. Do not
normalize or filter the differing RNG calls to make the checker pass. Decide
and test a link-visible protocol revision for the changed native battle
behavior; current green fingerprint tests alone do not prove mixed-version
link safety.

Remaining adjacent lifecycle work includes native timed Lock-On ownership
(the existing one-use host pointer keeps its previous lifetime), whole-game
RNG/VBlank scheduling and the demo controller's midpoint battle RNG/playback.
This branch does not claim those producers or a full tutorial playthrough.
