# Native coroutine phase ownership

Native script bodies and Game3 methods remain owned by their existing native
call sites. An actively resumed source child can consume its parent's body once.
A suspended child cannot lend a phase or callback owner to an unrelated caller.

The shared scope registry selects a coroutine's own active phase before inherited
ones. Nested related phases retain their ordinary order. Ambiguous independent
roots do not lend authority. Parent return retires pending children and borrowed
body claims; their later cleanup cannot restore an expired phase over a newer
one. Retirement also prevents that source coroutine from acquiring another
registry's authority or flushing pending Pokemon writes. Weak heads/locals do
not pin an abandoned coroutine; child registries are allocated only when needed.

Native failures, including false-valued errors, cannot be swallowed and retried.
Existing source/native return tuples retain their nil positions. The native
controller remains the simulation clock; no action queue or animation sequence
is introduced.

## Limits and qualification

This is prerequisite safety work for source-controlled action presentation. It
does not create Engine.resolveMove, an action plan, animation event filtering,
interactive choice policy, or a complete HP/RNG continuation guard. Arbitrary
Lua statements already suspended inside a native body cannot be rolled back or
preempted by a scope registry. The action Card remains gated until its complete
native execution and presentation contracts are qualified.

Retained baseline `ad7f267d73` reproduces suspended child leakage, consumption of
a newer caller's body and restoration of an expired phase on source `97452fb1`.
Focused source `029e4c5917` passes48 script-phase and30 game/callback tests, plus
existing callback, follower, script, field, battle menu, fly arrival and Gen2
lifecycle groups. Whole-source and exact older-public composition qualification
follow separately; private mod code and player profiles are not changed.

## Frozen combined qualification

Native code `52a40875` / frozen `22c20c029b` passes all121 selected CPU groups.
Exact older-public composition `27cb70b9bb` passes54 groups, including48
phase tests,30 callback/game tests and467 real script-space ownership checks.
It applies only the shared once-only helper and published Game3 adapter changes;
older native controller bodies remain unchanged. The first raw script-PR probe
retains a missing NativeSession prerequisite; it is not claimed as an integrated
pass. The raw offered phase helper separately passes48 checks.

The unchanged private package completes Ruby new-game/naming, real native map
cancel/reopen and flight on this frozen source in run `353d5c5f1d`. Landing setup
is ready under the opaque transition, then the player reaches Littleroot5,9 with
free input,355050 vertices and no mod/renderer errors. Its stationary240-frame
Metal observation averages16.330ms, with p95 24.786ms and max142.098ms. This is
not a stable-sixty-FPS, all-view, continuous-story or visible-desktop claim.


Current-main follow-up: merge `8d532c3f` incorporates main `7d1e243b`, preserving
its native RS battler positions, double-battle EXP participants and shared quad
fixture methods. Frozen source `ddd4035807` passes125 selected CPU groups,
including the four newly selected position/import/EXP/residual groups.
Unchanged-mod Ruby run `9eff111d1a` completes native Archie trainer entry,
paper/native/terrarium/native/paper switches and transitions, move swap/cancel
with unchanged HP/PP, and native dex/list owner retirement. Inspected native and
terrarium captures are upright. Prepared fresh-profile checks do not establish
continuous story, stable performance or visible desktop acceptance.
