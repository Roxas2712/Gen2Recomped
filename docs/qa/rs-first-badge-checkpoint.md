# Continuous first-badge checkpoint lineage

The ordinary-input RS driver can complete NEW GAME through the first badge,
but its report predates two lineage summary booleans used by the earlier
lab-checkpoint driver. Its successful result could therefore not be resumed.

Qualification now derives that lineage from the unchanged recorded input
trace. It requires a passed first-badge run, NEW GAME and empty-party facts,
Pokédex receipt, the first empty-to-single-party transition at native starter
selection on Route 101, the actual recorded A input, a level-five starter
and the native wild level-two Poochyena rescue battle. Its single first-party
event must match that exact starter and fall inside the command's frame
range. Existing frozen-source, isolated-profile, no-injection, witnessed
SAVE/YES, save-byte and saved-tail checks still apply. Failed or incomplete
runs cannot use this path. No report is modified or relabelled.

Fourteen guarded Python tests cover both editions, both established origins,
the new trace proof, missing/changed inputs, injected parties, wrong maps,
wrong battles, missing/duplicate/out-of-range events and report immutability.
No production gameplay or save format changes.
