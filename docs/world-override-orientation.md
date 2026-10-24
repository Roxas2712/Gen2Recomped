# Legacy world orientation on LÖVE 12

The native preview bundles LÖVE 12. Its clip-space normalization changes the
result of legacy custom 3D shaders that already invert clip-space Y for LÖVE 11.
Unmodified Voxel Ascendant rendered a vertically inverted world in this preview,
including Red's house, while the separately composited UI remained upright.

The renderer keeps the producer's orientation with its returned world image.
Legacy Gen1–Gen3 world pipelines receive one vertical presentation mirror on
LÖVE 12, on both OpenGL and Metal. LÖVE 11 and native Gen4+ world images keep
their existing presentation. Engine-drawn field effects are counter-mirrored
inside the legacy image, preserving both their projected anchors and artwork.
The UI is composited separately and is never mirrored by this correction.

A pipeline that draws an already upright image using ordinary 2D drawing or
current clip coordinates can declare `worldOrientation = "native"` in its
`render_pipelines` definition. `worldOrientation = "legacy"` explicitly requests
the legacy convention. Detached `worldFormat = "renderData.v1"` pipelines retain
their native image convention. The optional metadata is additive; existing
legacy 3D mods need no source or manifest edits. A custom `render.compose` hook
receives `ctx.worldOverrideMirrored` with the image it is taking over.

`tests/engine/world_override_orientation.lua` exercises the real compositor,
separate UI, canvas lifetime and native field-effect transform using recording
graphics calls. GPU acceptance must additionally use asymmetric pixels and
inspect real mod scenes; merely finding a non-black or changing image cannot
establish the correct orientation.

## Acceptance on the composed native preview

Source `ddb20a6989c7281bbfb5314c93d56de280c498a6`, engine 0.8.45 / API 3,
pinned official LÖVE 12 `937eb3b21f973607ab080aa26b7ef2a6b3b2b663`:

- Real Red with unchanged Voxel Ascendant 3.0.65-rc.4 and Kanto Ascendant
  6.7.35-rc.2: First/Third Person outside and in Red's house, actual V switch,
  eight owned OS-window captures visually checked upright across both backends.
- OpenGL: 590/590 world images returned. Metal: 626/626 world images returned. Detailed
  receipt: `docs/validation/love12-world-orientation.json`. No runtime mod errors.
- Asymmetric GPU oracle: red world top/green bottom, yellow FX cap/magenta
  stem at their expected anchors and upright blue UI; legacy 3D, native 2D,
  detached Gen3 and native Gen4 presentation conventions all pass on OpenGL
  and Metal. These last two are compositor fixtures, not full Gen4 gameplay.
- Negative control disables only the mirror policy in the isolated test
  process and fails the red-top assertion, reproducing the original error.
- 117/117 CPU compositor/FX checks; complete ROM-free quick suite passes all
  tiers; preview package tests 7/7. The independent upstream patch also passes
  the same 117 checks without the rest of the fork integration.

`tools/world_orientation_gpu_driver.lua` is the repeatable pixel oracle. Run
it via `POKEPORT_DRIVER` in an explicitly isolated fused preview with its own
Red import and no mods, set `POKEPORT_ISOLATED_TESTING=1` and point
`PALETTE_GPU_OUT` at a new results directory. The complete engine frame wrapper
performs the readback; the driver does not nest frame presenters. VASC tests
use the real mod pipeline separately and never alter mod source or manifests.

The initial ad-hoc pixel harness nested the frame wrapper and could not read
an active target. That harness was corrected; it was not a production renderer
regression. Windows hardware execution, all VASC features and complete engine
parity remain open. Map changes in these smoke tests use the teleport test
helper, not ordinary door/warp traversal.
