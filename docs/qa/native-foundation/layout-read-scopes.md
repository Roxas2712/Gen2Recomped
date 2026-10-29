# Synchronous native layout observation scopes

Contributions by Roxas2712. Existing source licences and credits remain applicable.

`Map.withLayoutSnapshot(game, callback, ...)` shares the first admitted layout
observation of each owned map only during one synchronous callback. Repeated
reads keep the original definition object, native identity and ownership checks.
The callback receives its supplied arguments and returns its exact result tuple.
Ordinary reads resume on return or exception; callback errors retain identity.
Older or inactive sessions execute the callback without acquiring observations.

Use this for a coherent drawing transaction, never around simulation updates.
Native map/collision objects are not mutated or frozen: native writes take effect
immediately, while the opted-in presentation transaction retains its observation.
The next scope observes the current native revision. Nested scopes observe fresh
state and restore their caller; explicit invalidation retires held observations.
Dataset/session retirement prevents restoring a previous owner's scope.
`Map.layoutSnapshotStats(game)` exposes aggregate read/hit counts without Shader
wrappers, GPU fences or per-read allocations. Outside a scope the normal path
remains active; no global frame cache or mod option changes are introduced.

The regression uses actual map-runtime fixtures for all five GBA editions,
including native writes, nested scopes, identity, invalidation, exceptions and
nil-bearing return tuples. The separate map-view proxy prototype changed native
ownership and failed its image check; that approach is not used by this API.
Native image and FPS qualification remain necessary before a performance claim.
