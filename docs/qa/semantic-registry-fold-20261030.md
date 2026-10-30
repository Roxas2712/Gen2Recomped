# Authored patches survive owner arbitration

Contributions by Roxas2712. Based on PR #402; independently implemented for
the native registry and Unified content adapters.

The audit's patch-fold candidate was reproduced: a native mod appended a
level-10 move, a Unified mod appended a level-20 move, then the first owner was
removed or excluded by preference. Both cases incorrectly retained the first
owner's move inside the second mod's precomputed native list. The baseline
test failed both cases.

`Registry:patchTransformed(id, partial, owner, transform)` now keeps detached
authored intent and converts it against the surviving row during the ordinary
memoized fold. Conversion is probed before registration. Frozen/compose
refusals and native numeric IDs remain explicit. Owner filtering happens before
conversion, and rollback invalidates the fold cache.

Unified Pokemon, move and trainer patches use this boundary. Detached
read/modify/write records first discard their unchanged inherited fields and
read-only native metadata. The conversion retains native selectors and exact
list-clear behavior. Canonical ID vocabularies are prepared before folding to
avoid a recursive lookup through the record currently being converted. A
patch does not resurrect a row whose registering owner was removed.

Touched native base rows are retained separately from the live Data target.
Writing the merged value back into Data must not turn that result into the
base of a later owner preference or rollback. This also fixes native-only
post-merge arbitration and restores iterator membership after a tombstone.

Validation: `registry_transformed` (21 checks), `unified_content` (501 checks,
including the reproduced rollback/preference cases in Gen1, Gen2 and Gen3),
and twelve existing native/Unified content, dataset and API3 suites all pass.
The latter include native phone, radio, landmarks, apricorns, decorations,
held items, marts, AI classes and ROM text. No ROM or player/mod installation
is used. These checks do not qualify rendering or unknown published mods.
