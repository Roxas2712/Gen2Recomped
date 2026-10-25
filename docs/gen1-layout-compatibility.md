# Legacy decoded layout compatibility

Compatibility map observations use `src.compat.gen1.DecodedLayout` for owned
decoded 16px snapshots with `fromDecoded(decoded, mapId, pair, sourceBlob)`.
The existing `src.core.game3.layout_native` continues to provide live native
map handles; its constructor has a different partial-cell/write contract.
Transparent constructor selection for unchanged consumers remains open.
The module supplies the original sampling, overrides, batch/stamp operations,
collision array, revision and packed-worker snapshot contracts.

Authored width/height and true map dimensions stay separate. Padded and
negative-coordinate samples use the tiled border; padded collision-array
cells remain blocked. Base cells keep their identity and overrides do not
mutate the decoded source. Duplicate batch writes compose in order and advance
one revision. Classified collision bytes, explicit zero and elevation 15 are
preserved. Up to 64 writes invalidate individual view cells; larger writes,
stamps and resets request full invalidation.

Packed-worker snapshots retain immutable source bytes and detach border and
override metadata. Custom samplers, changed dimensions/cell ownership and
asset overrides reject that packed shortcut, allowing the caller's ordinary
sampled fallback. This follows the original host's contract; decoded source
cells must remain immutable while using its original packed bytes.

`coll` is the legacy host's classified `COLL_*` byte, **not** the native grid's
raw two-bit collision value. This module does not translate the two schemas
or bind these mod-owned layouts to the game's current map. An old map/session
adapter must own that translation and lifecycle explicitly. Native walking,
elevation, scripts, saves and caches are not changed by this module.

Verification runs the same consumer against the snapshot adapter and the layout module on
the public v0.3.94 reference runtime at `37a49b31f458d51ea9e00b90f2a247272ad09cb8`
and the tested source snapshot. That source reports 245 checks and a matching
cell-sampling signature; the current composed fork must be qualified separately.
Coverage includes borrowed/copied identities, negative borders/padding,
partial cells, zero fields, duplicate writes, source invariance, revision and
invalidation thresholds, custom-sampler rejection and detached worker data.

```sh
python3 tools/gen1-layout-compat/check.py --gen1 /path/to/pinned-gen1 --lua luajit
```

The consumer needs no ROM, graphics context or player profile. This is not a
live-map/GPU test or an Origami 1.0.9 acceptance. Its unchanged entry still
requires the missing `src.core.game3.map` contract and the remaining native
session, atlas, battle and presentation boundaries.

## Connection coordinates

`src.core.game3.connections` supplies the matching pure map-view contract:
cardinal aliases, array/keyed definitions, parallel connections, authored
layout dimensions, incoming overlap, destination-local coordinates and
directional boundary lookup. Dive/emerge records remain outside cardinal
placement. It does not load neighbors, mutate positions or replace the
native world's connection controller.

The identical reference/native consumer checks 12,160 cases and compares
the entire result stream for four cardinal directions and their aliases,
negative/zero/positive offsets, overlapping connections, unavailable
destinations and edge/corner samples. Source connections remain unchanged.
These checks run with the same command above alongside decoded layouts.
