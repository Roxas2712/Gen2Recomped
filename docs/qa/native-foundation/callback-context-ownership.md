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
