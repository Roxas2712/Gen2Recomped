# Continuous first-badge checkpoint lineage

The ordinary-input Hoenn driver can complete NEW GAME through the first badge,
but its report predates two lineage summary booleans used by the earlier
lab-checkpoint driver. Its successful result could therefore not be resumed.

Qualification now derives that lineage from the unchanged recorded input
trace. It requires a passed first-badge run, NEW GAME and empty-party facts,
Pokédex receipt, the first empty-to-single-party transition at native starter
selection on Route 101, the actual recorded A input, a level-five starter
and the native wild level-two rescue battle: Poochyena in Ruby/Sapphire,
Zigzagoon in Emerald. Emerald also requires its own starter screen's selected
YES confirmation. Its single first-party
event must match that exact starter and fall inside the command's frame
range. Existing frozen-source, isolated-profile, no-injection, witnessed
SAVE/YES, save-byte and saved-tail checks still apply. Failed or incomplete
runs cannot use this path. No report is modified or relabelled.

Emerald's original battle wipe can still cover the pending rescue when the
starter-confirmation receipt completes. Qualification may follow up to eight
recorded waits, within 1,200 native frames, to that same battle's untouched
introduction. Every wait must contain no button inputs, keep the identical
starter and position on Route 101, retain the running rescue script, and show
only the native field fade/battle transition or the correct level-two wild
Zigzagoon intro with no completed turns. The first-party event must still fall
inside the original confirmation command, not a later wait. Missing receipts,
intervening commands, changed parties or battles, and unrelated UI remain
rejected. This reads the existing trace; it does not advance or rewrite it.

Guarded Python tests cover all three editions, both established origins,
the new trace proof, missing/changed inputs, injected parties, wrong maps,
wrong battles, missing/duplicate/out-of-range events, bounded input-free
Emerald fade receipts, changed positions and parties, and report immutability.
No production gameplay or save format changes.
