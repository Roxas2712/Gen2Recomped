# Gen1Recomp decoded layout compatibility

Existing mods can require `src.core.game3.layout_native` and construct their
decoded 16px layouts with `fromDecoded(decoded, mapId, pair, sourceBlob)`.
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

`coll` is the Gen1 host's classified `COLL_*` byte, **not** the native grid's
raw two-bit collision value. This module does not translate the two schemas
or bind these mod-owned layouts to the game's current map. An old map/session
adapter must own that translation and lifecycle explicitly. Native walking,
elevation, scripts, saves and caches are not changed by this module.

Verification runs the same consumer with the same original require name on
public Gen1Recomp v0.3.94 at `37a49b31f458d51ea9e00b90f2a247272ad09cb8`
and this engine. All 245 checks and the full cell-sampling signature match.
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
