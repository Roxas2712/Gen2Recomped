# Native GBA move-used and PP command ordering

Development branch, stacked on #241 and the existing #161 charge-decision
producer. Full acceptance and PR publication are pending.

Ordinary GBA attack strings emit `battle.move_used` before the selected PP
command. The command reads the current selected slot and Pressure abilities
after callbacks, rather than spending a retired learned record. Removing a
slot does not cancel an already admitted attack or spend a different slot.

Zero-PP admission is decided before the event. Such a failure still emits its
attack-string event, then refuses the move without animation, damage or a
move-end command. A callback refill cannot retroactively admit it. A failed
spread action must not continue attacking its remaining targets.

Charge commands are different: the charge-decision hook precedes PP reduction.
A retained first charge consumes PP without an attack-string event. Hook
bypass and native sunlight consume PP before the subsequent event. Release
does not consume a second PP. Non-GBA ordering is preserved.

The new shared fixture executes unchanged native scripts for FireRed and
Emerald. Its 408 rows retain event-visible PP, the public API-3 move records,
the next subscriber's view after native callback changes, charge-hook PP, all RNG,
current/retired PP and all active HP. They cover ordinary, Pressure, one/zero
PP, callback refill/edit/replacement/removal, changed Pressure, forced slots,
actual Sleep Talk, awake/asleep failures, authored `ctx.callMove`, Struggle,
charge/release/bypass/sunlight and spread targets. Callback mutations are
controlled native fixture inputs; this does not introduce a new public PP
writer or promise writeback of event snapshots.

All 408 rows currently agree. The exact composed prerequisite fails 360 rows
with that same fixture. Raw initial failures and corrected results remain in
`tmp/move-used-pp-qa/`. The actual host/guest/spectator test passes 84 checks
over two menu-driven turns per profile, with a stateful public held-damage
consumer depending on event-visible PP. The first linked probe attempted to
write an event snapshot and lacked a two-turn input barrier; its failed raw
result is retained separately from the corrected read-only public consumer.

The fixture also repeats actual planning before charge release, including
release after the last PP was spent. A wrapped action must release the stored
move by identity, rather than charge again or refuse for zero PP. The exact
previous module fails 24 rows for this case; the fixed path clears charge and
invulnerability, deals native damage and spends no second PP.

Native command revision is 12; party codec remains 1. An independent audit
applies only token 11 -> 12 to the unchanged prerequisite hasher and reproduces
`6ce58ced7ffad4d9`; older-generation digest `e33d251961f2a41d` stays unchanged.

Pending: final clean full feature/combined suites, complete default contract
matrices, existing charge-decision regressions in all formats, actual imports,
format/workflow checks and publication. The unchanged composed parent passes
144/153 engine suites, SDK 3/3 and B30, retaining the same 25 inherited FAIL
lines as #241. Other native command boundaries, special callers such as Nature
Power, complete held-script orchestration, catalogs and graphical playthroughs
are not certified by this bounded fixture.
