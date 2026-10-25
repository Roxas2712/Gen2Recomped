# Native GBA Mirror Move work in progress

This development branch builds on Gen2Recomped #258. It is not yet an accepted
PR or a replacement for the combined testing branch. The unchanged Gen1
reference is read-only at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

## Implemented gameplay path

GBA Mirror Move reads the recipient's received-move history at its native
command, instead of the current target's last selected action. Native move-end
updates this history using the chosen caller's mirror flag after item commands.
Misses, protection, immunities and fainted recipients do not replace it.
Called moves use the existing native child targeting and PP handling. A
registered Mirror Move has no caller animation of its own. The new volatile
history participates in native link signatures; command revision 16 rejects
older semantics. Party codec revision stays 1. The frozen parent serializer
with only the revision token changed independently yields `b251a4d1054d6555`;
legacy game digests remain `e33d251961f2a41d`.

## Evidence and remaining work

The original 80 command sequences had 68 differing full observations on #258.
The first implementation matches all 80, retaining complete captured events,
held reads, RNG, PP, damage, actor state and move-animation metadata.

The expanded native, API-3 registered and Metronome -> registered Mirror Move
matrices execute 1,920 paired observations. All workers exit zero. The complete
comparison is still **failed**: 144 observations differ in Substitute animation
commands. These differences are retained without removing rows or fields.
Actual default animation playback and Substitute transitions must be addressed
before accepting the wider matrix or publishing this PR. Broader history
command conditions, linked-role tests, actual-import scenarios and full
regression checks also remain required.

Both public APIs reject raw `flags` fields and new writable `native` diagnostic
envelopes. The fixture's initially invalid registrations are retained as failed
observations; the valid registration uses only public fields. Imported/native
moves retain their flags. Newly registered incoming moves with default metadata
are tested separately; this branch does not invent a public flag-writing API.

Raw successes, negative controls, fixture corrections and failed expanded
comparisons are kept in the ignored local `tmp/mirror-move-qa/` directory.
The fresh #258 baseline remains 157/166 engine suites with the same nine inherited
failing suites; this branch has not yet completed its full regression gate.
