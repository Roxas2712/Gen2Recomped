# Gen-4 vertex unpacking

`Gen4Model.unpack(shapeBytes, opts)` delegates to `src/render/Gen4Unpack.lua`.
It creates CPU data and optional `love.data` ByteData, without graphics calls.
Mesh creation, texture attachment, back-wall generation, grass-card creation
and legacy-cache warnings retain their native owners in `Gen4Model.new`.

Options carry vertex/triangle counts, indices, matrix slots, texture name,
`unlit`, `lightKnown`, `noFog`, `posScale`, texture width/height, `hasImage`,
`shade`, `fog`, `billboard`, `capBack` and `tileUnits`. `flags` carries
`gen4ByteVertices`, `gen4GpuSkin` and `gen4GpuLight`; `modelFlags` carries
`legacyLight`. The renderer supplies its format width through `formatFloats`.

The synchronous caller passes the original `shape`, `record`, Performance
and model flag tables. The decoder reads those tables at the same points as
before extraction. In particular, a custom shade callback can replace later
vertex bytes or edit `noFog` during the loop. Inputs are not rewritten, and
CPU-skinned vertices remain tables. Callback results and floating-point
operation order are unchanged.

The result contains `count`, `vertices`, optional `packedData`/`packed`,
`positions`, `lo`/`hi`, `gpuSkin`, `stride`, `uLo`/`uHi`, `cards` and
`grassPending`. Positions and bounds retain double precision even when the
upload stream contains float32 values. The FFI pointer is local CPU state;
a future worker boundary must return channel-compatible values instead.

Run `luajit tools/gen4_packed_vertices_check.lua` for graphics-free
packed/table equality, legacy strides, CPU/GPU skin paths, lighting/fog,
classification and live callback edits. For all native Twinleaf shapes,
`python3 tools/check_gen4_unpack.py --help` describes the fresh-import test
against a pinned pre-extraction Git renderer. It compares upload bytes and
public model metadata in both table/packed and CPU/GPU lighting modes.
This extraction starts no workers and claims no speedup.

Qualification at `85f5bb67`: 146/146 focused/native/compatibility/matrix
stages passed, including the native rendering host. LÖVE 12/Metal and
LÖVE 11.5/OpenGL each compared 10,208 uploads from 172 unique chunks and
2,519 shapes in the native Twinleaf matrix: 105,936,384 vertex bytes per
runtime, zero differences. Live callback/getter sequences also matched the
pinned `2fdfe77f` renderer. These checks measure byte/behavior equality;
no runtime speedup is claimed. Raw reports are in `docs/qa/gen4-unpack-*`.
