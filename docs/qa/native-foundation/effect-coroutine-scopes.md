# Effect observations follow the current native coroutine

The native effect registry still calls its actual primary, perform and damaging
callbacks with their original context and return values. Its source observation
adapter now uses the shared coroutine scope authority instead of a global stack.
A suspended sibling is unavailable to a caller or an independent native effect.
An actively resumed effect keeps its own context even when its resumer enters a
newer native root. Nested calls retain their actual ancestry and depth.

A retained descriptor or RNG closure requires that exact visible native effect
ancestry. Revoked callbacks cannot acquire its RNG permission again. Public
views hold only a weak lease, so an abandoned coroutine and its native controller
can be collected while an external descriptor remains. Closing a suspended
phase cannot restore it over a newer root. Nil tuples and native errors retain
their existing behavior. Gen2 keeps its direct callback path.

This is observation/RNG permission safety. It does not preempt arbitrary Lua
statements or supply a complete HP/RNG continuation for Action Card. Resolver,
action phase and contact admission remain gated. Default combat behavior and
native effect execution are covered by existing native regressions.

The direct coroutine fixture first admits native slot placement through
`syncSides`, normally established by entry/turn resolution. Five intermediate
failures came from the fixture skipping that native placement; no production
placement or assertions were weakened to fix the probe. Initial retained global
stack negatives and final predecessor/qualification receipts are separate.
