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
revision-token audit reproduces `3e2986da83083f86` using the unchanged #230
hasher and only revision 10 -> 11; older-generation digests remain unchanged.

GBA Struggle skips STAB and the type chart while retaining its normal base,
critical and random-damage commands. The new planned-execution comparison
exposed this existing damage gap, including excess recoil.

Real link simulations run held scans and planner/speed reads in canonical
host/guest order. The initial item-entry batch waits for both send-outs;
later individual switches keep their normal entry command. Host, guest and
the actual spectator compare complete ordered held traces, including entry,
priority, damage, move-end and residual calls. A stateful damage override
depends on all earlier reads. No payloads are filtered from this comparison.

## Development evidence

Before final fixture formatting, focused comparisons pass against the clean,
unchanged Gen1 reference: 80 move-end rows, 180 selection-mask/manual rows,
228 planned/executed rows and 288 ordinary-wild selection/planning rows.
The planner rows retain all recorded RNG calls, events, HP, learned moves,
current/replaced PP and complete planner held payloads. Their execution phase
does not record the full held-script trace; the separate command and link
probes have their explicitly different boundaries.

Public Loader snapshots/submission, stale offers and the actual keyboard /
message queue refusal return pass 134 assertions. Actual host/guest/spectator
menus and two completed turns pass 86 assertions, with all captured held
reads and peer state components equal. Final formatted reruns, full suites,
negative controls, more caller/switch coverage and import acceptance are
still required. These are development results, not PR acceptance.

Retained local evidence lives under `tmp/choice-band-qa/`: failed
`planning-first`, `planning-unbound-fixed`, `wild-first`, `public-first`,
`link-first`, `link-canonical-order` and `link-spectator-first` probes;
passing `selection-fixed`, `planning-struggle-fixed`, `wild-input-fixed`,
`public-helper-fixed`, `link-canonical-all-phases`,
`link-spectator-input-fixed` and `hash-audit` results. Early planner/wild/UI
fixture errors and genuine runtime mismatches are kept separately in those
raw outputs. Initial full link traces failed even when turn hashes matched.

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

No complete feature/combined acceptance or PR publication is claimed yet.
