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
