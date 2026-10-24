# Gen3 surface render data v1

`mod.renderData` now also exposes independently negotiated surface observations:

```lua
local r = mod.renderData
if r and r.supportsSurface and r:supportsSurface(1) then
  local cells, reason = r:surface(1, expectedActiveMapId, {
    mapId = residentNeighborId, -- optional; defaults to the active map
    region = { x = 0, y = 0, width = 16, height = 16 }, -- optional
  })
end
```

Support means the host implements this Gen3 contract. A title screen or an
unavailable map can still decline an individual read. No manifest version bump
or new permission is needed; API 1 and API 2 consumers retain their existing
content, events, hooks, logging and file-read surfaces.

The result contains every field of [`snapshot(1, ...)`](gen3-render-data-v1.md),
plus three dense arrays in exactly the same cropped row-major order as
`metatiles`:

| Field | Values | Native source |
| --- | --- | --- |
| `elevations` | integers 0–15 | cell elevation with `elevationPatch` applied |
| `collisions` | integers 0–3 | cell collision bits with `collisionPatch` applied |
| `behaviors` | integers 0–255 | combined tileset behavior for the **live** metatile |

Coordinates are zero-based 16-pixel cells **local to the selected map**.
Placements describe the already resident maps relative to the active map, as
in the terrain contract. A neighbor read still requires the **active** map ID
as its guard. A caller must translate the selected placement separately.

Elevation codes are cartridge semantics, not distances in pixels or meters:
0 matches any elevation, and 15 marks a multi-level/under-bridge cell. Preserve
those values when deciding how to render a bridge. Collision bits alone do not
answer walkability: water rules, actor elevation, events and scripts also
participate. This API neither runs movement nor classifies a cell as a house,
tree, roof, bridge, water reflection plane or walkable destination.

Zero-valued runtime patches override nonzero base values. The behavior follows
the patched metatile, including primary/secondary tileset boundaries and indoor
tilesets. As in native `Map:cellElevation`/`cellCollision`, absent entries of a
present elevation table default to 0; an absent collision table defaults to
0 while retaining collision patches. A missing elevation table, missing native
behavior table, or non-Gen3 behavior vocabulary declines the whole read.
Malformed present values never become plausible zeroes.

Reads use only the resident map, live patch tables and combined tileset.
They do not invoke map loaders, native map queries, layout decode caches,
graphics, filesystem, Game boot or RNG. Returned arrays and placements are
detached from the engine. The reader retains no snapshot cache.

The terrain query's existing restrictions and errors apply: at most 4096
cells per call, bounded map dimensions and resident placements, exact query
keys, and no unloaded-map reads. Surface-specific failures return `nil` and
`"surface data unavailable"` (missing/malformed source table or vocabulary) or
`"surface cell unavailable"` (missing behavior or invalid cell code). An
unsupported generation/version retains the terrain contract's explicit error.

Tests:

```sh
luajit tests/engine/gen3_surface_data.lua
luajit tests/engine/native_foundation.lua
```

The second test loads an actual mod consumer with no private imports, reads
terrain/surface, actors, field effects, mounts and their image sources on one
handle, and observes them inside the portable world callback. These are
ROM-free contract tests, not visual acceptance of First/Third Person or the
full Origami renderer.
