# Read-only native action order

The native turn planner already establishes order and queues its action bodies.
Observations now bind that actual order to those actual function rows. They do
not create an executable action queue, resolve a move, change an action or add
a frame. Native queue dispatch marks the executing row and retires it on failure;
the existing native end-of-turn retires the observation ledger.

The source battle facade exposes a detached `_actions` array with stable,
read-only action records and `_actionI` for its executing/physical head row
(one-based, zero when no mapped row owns that position). The move key and side
come from the actual queued native entry. The records describe selected commands,
not a prediction that the move will pass status, targeting or damage checks.

Edition, native dataset/save/loader/stack/queue and source admission changes retire
observations. Restoring a prior pointer does not revive the old lease. Unqualified
native act wrappers or replaced pending callbacks retain their behavior while
losing the verified observation; another function is never labelled as the
original native command. The observations retain no native controller through an
external stale proxy. Gen2 keeps its native dispatch and constructs no GBA ledger.

## Qualification and limits

Focused qualification passes782 checks, including real native move-used producer
observation, typed pairs/next iteration, detached arrays, stable identities, read-only records, cohort/source
retirement, callback replacement, unknown native wrappers and native failure.
Complete deterministic turns compare HP, PP, every RNG invocation and frame/phase
sequences with observation registration off/on across all five GBA editions.
The first comparison retained a mismatch because wild construction selected
random enemy IVs/personality before binding battle RNG. The owned fixture now
prepares identical mon records and shown HP for both runs; native combat is not
simulated. No player profile or private mod bytes are changed.

This is an observation prerequisite. `_phase`, `Ui.busy`, native execution and
animation sequence admission are unchanged. No resolver or sequence stub is
installed, and Action Card readiness stays gated. A typed native HP/RNG
continuation and real resolver/sequence ownership remain required before source
contact suspension can be admitted. Whole-source, predecessor and unchanged-mod
qualification follow separately.


Frozen source `f0627a735e` (before the additional nil/false loader hardening)
passes all126 selected CPU groups. Exact predecessor comparison `8c498caaf6`
executes the identical owned turn probe against that tree and predecessor
`ddd4035807` without overlaying either native controller. HP, PP, RNG invocations
and every frame/phase record match across all five editions. Latest source and
older-public integration qualification are recorded separately.

Final current-main code `5eca0614` (main `c4bd3b36`), frozen `f11ba60038`,
passes133 selected CPU groups including782 focused action checks. Exact
predecessor `f9fc881eb2` retains identical full-turn HP/PP/RNG/frame traces
across all five GBA editions. Older-public composition `c9eed01598` passes55
groups, retaining its older native controller bodies. Raw older-public execution
still requires the declared shared typed-iteration prerequisite; this is not
standalone upstream CI acceptance. The scoped CI workflow belongs to the complete
native fork, not the incomplete older-public prerequisite chain.

Unchanged package `bddb5181`, Sapphire run `567f801dd0`, completes native
new-game/field entry, paper battle, real RAGE selection (PP20 to19), player
HP63 to46 and enemy HP57 to49, then native/source cleanup without loader errors.
The after-move capture is upright. This owned prepared fresh-profile functional
run is not continuous story, visible-desktop or FPS acceptance.
