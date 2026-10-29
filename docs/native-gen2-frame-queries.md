# Native source Game2 frame queries

The source `Game2` class exposes `frameFit(w,h)` and `viewport(w,h)`.
The fork aliases that class name to its native `Game`, but neither method
existed there. An unchanged Gen2 battle scene consequently used its renderer
fallback instead of the source owner query. This is a concrete API gap;
it is not yet proof of the cause of a particular clipped command card.

Logical-window queries use the existing native `Gen2Chrome` policy. Queries
of the actual current drawable dimensions use framebuffer coordinates and
the native compositor's integer pixel fit. `PixelFit` extracts the existing
scale/origin arithmetic from `Renderer` so these paths share that policy.
The query returns scale/origin in the queried coordinate space, window DPI
and actual native drawable dimensions.
`viewport` returns a detached source-format classic 160x144 playfield
description. Querying does not install another renderer, resize a canvas,
alter the active compositor or change cartridge state. The existing
`render.hud` producer and the policies for other native surfaces are not
replaced by these methods.

The source contract was inspected in frozen Gen1Recomp revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, `src/core/Game2.lua`.
This integration uses the already native Gen2 chrome and viewport owners.
Existing engine authors' rights and applicable licences remain effective;
integration/tests by Roxas2712 are subject to `LICENSE-ROXAS2712.md`.

The initial implementation `5d9cc42e` passes 3161 checks using logical-window
inputs. It observes the same geometry as the actual native classic
compositor across Gold, Silver, Crystal, Prism and Polished Crystal, six
window shapes and DPI 1, 1.25, 1.5, 2 and 3. It checks logical versus physical
dimensions, pixel-aligned origins, detached returned state and unchanged
native fitting/cartridge state. The same committed probe on preceding
engine `8afbfeb4` fails cleanly because the methods are missing. Those checks
did not exercise the unchanged battle scene's framebuffer-sized arguments.

A real Metal run of candidate `3b57784c` reached a natural encounter with
unchanged VASC and the earned QA starter checkpoint. Four inspected OS
images cover the two selected field camera flags. It exposed the missed
case: at a 1024x768 window and DPI2, a 2048x1536 query returned scale10.5 and
origin184,12 while the actual compositor used pixel scale10/origin224,48.
That candidate is rejected for coordinate acceptance. Bottom command art
is also clipped; its cause is not attributed solely to this discrepancy.

The expanded unchanged SDK/compositor probe fails263 of4454 checks on that
candidate. Implementation `3a2fff04` passes all4454, including the recorded
Retina regression, actual drawable queries, odd pixel sizes and a decorated
native fit. Existing chrome116, playfield585, viewport56, macOS surface1296
and native battle-window315 checks also pass. The correction still needs a
fresh actual Metal observation and complete current-tree qualification.

This selected CPU proof does not establish every skin/cutout/safe-area or
custom surface configuration, odd-sized fractional-DPI logical queries, physical
Windows behavior or unchanged-mod GPU presentation. Matched Gen1/fork
window/target/letterbox observations and visible battle-actor pinning remain
required before claiming visual acceptance or a release fix.
