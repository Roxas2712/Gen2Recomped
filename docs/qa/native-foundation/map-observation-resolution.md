# Resolve native map observations once

Contributions by Roxas2712. Existing source licences and credits remain applicable.

A stationary rain/reflection VM sample placed repeated map view/runtime and identity
lookups among the active paths. Both consumers previously translated a canonical
name to a native slot, validated that slot, then translated the native key back.
Native-key input took another intermediate translation.

`MapIdentity.bind(...):resolve(id)` returns the native key, borrowed definition and
canonical presentation name from one record validation on an ordinary hit. The
existing name precedence, preferred same-object alias, ambiguity refusal, and live
record replacement/group/number checks remain. It creates no frame cache and never
freezes movement, scripts, terrain edits or room state. Map view revision stamps and
native cell reads remain unchanged.

Validation compares the combined result against the previous resolver for every
catalog entry and its aliases in all five GBA editions, plus removal, replacement,
ambiguous slots and same-object native aliases. The map-view and map-runtime checks
cover changed cells, neighbor layouts, revisions, ownership and retired sessions.

This is an observation-path optimization. The earlier rain/depth diagnostic does
not establish an FPS improvement from this change. A native comparison remains
necessary before claiming progress toward 60 FPS.
