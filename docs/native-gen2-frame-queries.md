# Native source Game2 frame queries

The source `Game2` class exposes `frameFit(w,h)` and `viewport(w,h)`.
The fork aliases that class name to its native `Game`, but neither method
existed there. An unchanged Gen2 battle scene consequently used its renderer
fallback instead of the source owner query. This is a concrete API gap;
it is not yet proof of the cause of a particular clipped command card.

The native Game now delegates the fit to its existing `Gen2Chrome` scale,
origin and screen-position policy. The query returns scale/origin in the
caller's window coordinate space, window DPI and native drawable dimensions.
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

On implementation `5d9cc42e`, the actual API2 SDK/class alias passes
3161 checks. It observes the same geometry as the actual native classic
compositor across Gold, Silver, Crystal, Prism and Polished Crystal, six
window shapes and DPI 1, 1.25, 1.5, 2 and 3. It checks logical versus physical
dimensions, pixel-aligned origins, detached returned state and unchanged
native fitting/cartridge state. The same committed probe on preceding
engine `8afbfeb4` fails cleanly because the methods are missing.

This selected CPU proof does not establish every skin/cutout/safe-area or
custom surface configuration, odd-sized fractional-DPI targets, physical
Windows behavior or unchanged-mod GPU presentation. Matched Gen1/fork
window/target/letterbox observations and visible battle-actor pinning remain
required before claiming visual acceptance or a release fix.
