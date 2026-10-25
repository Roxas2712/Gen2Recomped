# Native GBA Choice Band and move selection

Development branch; validation and publication are pending. Do not use this
branch as the accepted combined game-testing snapshot. Its parent is #230.

The native move-end command always performs its Choice Band held-effect read
unless the action was disobedient. A new choice remembers the selected native
caller, excludes Struggle and successful Baton Pass, and is cleared when the
move disappears from the learned slots. Losing the item does not erase a
still-learned choice. Each later planner query obtains a fresh held answer.

Manual admission is a separate consumer: it checks physical item 186, not
mutable held-effect metadata. The AI's four-slot limitations command uses the
held-effect hook and combines Choice Band with PP, Disable, Encore, Taunt,
Torment and Imprison. The ordinary wild controller only uses that mask for the
all-unusable shortcut; otherwise it draws nonempty native slots before the
planner applies the choice. Manual Torment also retains the Struggle exception.

Planning binds the actual forced learned slot's PP and priority while keeping
the declared turn event separate. A later replacement of the move table must
rebind PP to the current slot. Native caller provenance is explicit: Sleep
Talk and the unchanged native Mirror Move/Metronome selectors differ from a
custom handler's `ctx.callMove`. Active Baton Pass caller frames follow the
replacement battler slot. Generic custom callers retain their own move-end
command rather than inheriting the native caller's early return.

Choice identity participates in GBA link state and public-intent staleness.
The native command revision is 11; the party codec remains 1. The independent
revision-token fingerprint audit and updated native golden are still pending.

## Required validation before a PR

- Execute `tests/engine/gen3_choice_band.lua` and compare the same complete
  zero-damage move-end command inputs with unchanged, clean Gen1
  `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. The fixture records every held
  payload and RNG call; it does not filter the trace. These are command tests,
  not proof of the complete damaging attack script.
- Extend actual planned-turn tests to physical/effect-only items, suppression,
  loss/reacquisition, first matching slot/duplicates, empty PP, Struggle,
  Encore/Disable/Taunt/Torment/Imprison, priority, targets and move replacement.
- Exercise public snapshots/submissions and real manual refusal/return paths,
  including stale offers and preservation of other-generation behavior.
- Exercise native and custom called moves, failures, Transform and real
  synchronous/asynchronous Baton Pass. Retain and report any remaining full
  held-script trace mismatch; King's Rock/Shell Bell remains a separate gap.
- Run actual linked roles, old-peer refusal, independent hash audit,
  maintained-LuaJIT cross-engine comparisons and complete feature/combined
  suites. Compare the exact inherited FAIL Counter with the clean parent.
- Run imported-data scenarios, scoped AST-verified formatting and actionlint.
  Publish a regular English Gen2 PR only after acceptance; Gen1 stays read-only.

No runtime or contract test has yet been run for this development branch.
