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
Talk and the unchanged default Mirror Move/Metronome selectors differ from a
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

The first clean full contract matrix at `be88b1fd` retains a failed result:
eight host workers expose a delegated selected-slot PP regression in the new
ordinary-wild action records. The delegate now captures an already-bound
action's original slot too. All 16 focused workers / 220 paired rows for
the unchanged choices/arguments/records contracts pass after the correction;
the full matrix must be repeated before acceptance.

The repeated clean matrix at `32e69c0b` passes all 132 workers / 78,444 paired
rows. Its full engine run retains three additional compatibility failures:
existing public refusal wording and legacy native choice-handle identity.
Focused repetitions pass after retaining the existing reasons and keeping
selection-only fields private until planning consumes them. The real double
controller now plans each actor once, rather than planning its two left
actors twice; a new legacy/target/controller suite passes 84 assertions.

Additional focused native comparisons pass for actual Sleep Talk dispatch
with a physical Choice Band, including custom callers and failure paths;
real synchronous/asynchronous Baton Pass with the item; and an unchanged
authored API-3 `ctx.callMove("TACKLE")` handler. The latter exposed a genuine
canonical-ID resolution gap and outer caller bookkeeping; the GBA helper now
resolves the same canonical references and preserves both move-end commands.
Forced status-move planning also retains the resulting target byte in single
battles. Raw failed probes are retained alongside their corrected reruns.

Twelve actual imported FireRed/Emerald scenarios pass with `--choice-band`,
including three sleeping calls, item loss before waking/ordinary selection,
zero-PP children, empty/forbidden pools, early wake and awake failure. These
explicitly use GBA rules and constructed parties/public menus, without a
normal SAVE, ROM/data distribution, graphics or playthrough certification.
Final clean full/matrix repetitions remain pending.

Clean feature `9329838e` passes 142/151 engine suites, SDK 3/3 and B30, with
the exact same 25 inherited FAIL lines as unchanged #230. Its full native
matrix and both imported modes pass. The first combined candidate retains an
additional #162 explicit-unlimited-enemy-PP regression (260/261); native
finite-PP selection/planning now preserves that explicit non-link exception.
The API-3 positional action remains separate while API-1/2 native slot handles
retain their identity. Focused tests also verify the private target reaches
the actual right-hand opponent and learned move records remain unchanged.

A new actual failed Mirror Move comparison records every held read and all
RNG/events/HP/PP for 24 rows over both profiles. The unmodified reference
returns before move-end; the initial host incorrectly bound Mirror Move and
ran extra item commands. The corrected default-caller failure retains only
its separate after-action sweep. The raw failing host observation and source
reference are retained. This does not certify successful Mirror Move target /
history selection or Metronome catalog/RNG parity.

The later complete feature run at `a7b14c7d` passes 143/152 engine suites,
SDK 3/3 and B30, retaining the exact same 25 inherited FAIL lines as the
fresh #230 parent. The combined candidate at `fc41fcc5` passes 262/262 engine
suites, SDK 3/3 and B30. Both final cross-engine matrices were interrupted
for separately reserved graphics measurements. These completed full runs
do not certify the subsequently prepared missing-slot change.

That pending regression replaces the learned move/PP arrays after forced
planning and removes the selected slot entirely. The unchanged native PP
command permits the planned move without spending retired or other current
slots. Prepared Pressure controls also distinguish this case from a present
replacement slot, which must spend two PP. The expanded comparison now passes
all 276 rows over both profiles, with all recorded planner payloads, RNG,
events, HP and current/retired PP equal. The exact saved old module fails 24
rows, spending one or two PP from the retired slot. Full feature/combined
acceptance and publication remain pending.

The planning fixture observes final PP and move-used events, but does not
observe PP inside the event callback. A separate actual-script diagnostic
retains 72 rows over both profiles, including 48 mismatches: ordinary and
Pressure callbacks observe PP before reduction in Gen1 and after reduction
in Gen2; zero-PP native failures still emit the event whereas Gen2 does not.
The first probe incorrectly supplied a selected PP slot for a called child;
native `run_called` supplies none. That first diagnostic is retained separately
from the corrected 72-row probe, with the same complete observation fields.
All raw rows are retained. This gap remains open; final-state equality does
not prove native event/PP-command timing.

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

Mirror Move/Metronome selector/catalog/RNG parity, the complete held-script
King's Rock/Shell Bell phase, other attack-canceller phases and full native
playthrough/graphics remain separate gaps. The new caller provenance alone
does not certify those selectors or full scripts.
