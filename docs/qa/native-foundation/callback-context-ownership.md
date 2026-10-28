# Source callback context ownership

An API3 owner that imports the Game3/battle namespace receives the same admitted
battle identity in callback contexts as `Battle.getState()`. Its battler IDs use
the actual native slots, and move numbers derive from imported move definitions.
Native/follower-only consumers retain their native handles, including event
payload identities. Namespace selection already exists; no mod rewrite or
manifest-specific conversion is introduced.

A source can copy a bound context to wrap its RNG, retaining the same native
transaction and opaque battle identity. Foreign battle identities and changed
move-number facts cannot be committed. A copied context remains a record, not a
second native action or combat executor. An RNG override is lent to the actual
native invocation and restored afterwards if still owned by that transaction.

Only actual record views create a coroutine lease. Native-handle hooks such as
core.update can legitimately replace a native save during their body. Record
transactions validate phase/cohort/battle before staging and before applying
writes. Their RNG handles require the same visible native ancestry and close
with the transaction. Public RNG closures hold weak leases. Source event
transactions also close on return/error.

Both native hook walks reject revoked coroutines before entering/falling back to
vanilla and before returning a cached result. A source yielding before or after
next cannot use a fallback or late commit to advance HP/RNG after its parent
phase has returned. Existing ordinary failure fallback/once-only/nil-tuple
behavior remains covered by the native hook and callback regressions.

This is prerequisite safety and callback data interoperability. It does not
preempt already-suspended arbitrary Lua statements, provide a complete native
HP/RNG continuation, install a resolver or enable Action Card. Native default
combat, Gen2 and native-owner ABI qualification are separate explicit checks.
Player saves and private mod files are not changed by QA.

Native production `4c7b4c0a`, merged with main `ea1b3a83` as `4ddf42e1`,
frozen `e8d798a271`, passes148 groups. The same frozen source additionally
passes native GSC vanish/checkpoint and trainer-phazing groups (1490/108/355
checks), making151 selected groups in total. Focused qualification passes216
context checks, including actual Loader-installed source/native pass-throughs
with identical complete native HP/PP/every-RNG/frame traces in all five GBA
editions, plus1816 existing unified callback checks. The older135-check negative
`cb0980b06f` reproduces63 failures, including17 stale native HP lost and RNG
consumption after parent return. The final expanded fixture is qualified
separately; the initial negative is not an identical216-check comparison.

Unchanged OASC109 `bddb5181`, Ruby `3c7d87b493`, completes native new-game,
GRUNT_003 trainer entry, paper/native/terrarium/native/paper views, native move
swap/cancel, actual RAGE (PP20 to19, enemy HP66 to58), dex/list retirement and
clean source teardown with no loader errors. Owned prepared fresh profile;
continuous story, visible desktop, stable FPS and complete Action Card remain
unqualified. The Mac was locked. No private mod or player profile was changed.
