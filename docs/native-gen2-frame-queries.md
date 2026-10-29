# Native source Game2 frame queries

`src.core.Game2` resolves to native `Game`, but the native class lacks the
source `frameFit(w,h)` and `viewport(w,h)` observations. An unchanged Gen2
scene therefore uses a fallback instead of asking its source owner.

Add passive queries through the existing Gen2 chrome and native viewport
owners: logical scale/origin, window DPI, actual drawable dimensions and
a detached classic 160x144 viewport result. They do not replace native
composition, mutate the cartridge or allocate another scene renderer.

This offer is based on the native viewport/touch stack in PR383. It includes
the already offered Chrome component from PR224 with all of its required
pieces: `Gen2Chrome`, its module alias, its palette-owner extension and its
tests. Inverted font ramps must be reversed after display-mode selection
and before the hardware shade-register permutation; the optional native
`effectiveColors(c,invert)` argument supplies that operation without a
second palette state. Calls without the optional flag retain their behavior.

Selected validation on offered implementation `5e4ee81f`:

- 3161 frame-query checks through the actual API2 SDK and the actual older
  native `Renderer:endFrame` compositor, across five GSC editions, six
  window shapes and DPI 1, 1.25, 1.5, 2 and 3. The newer fork's `frameRects`
  observation helper is not invented on this older host.
- 116 native menu-chrome checks, including inverted palettes with a
  noncommuting shade map, real font/box drawing and input/list behavior.
- The same frame-query probe fails cleanly on the preceding PR383 source
  `a3f0d344` because the two methods are missing.

Complete combined-host tests, every custom skin/cutout/safe-area and odd
fractional-DPI configuration, physical Windows behavior, matched unchanged
mod GPU/actor pinning and release acceptance remain open. The concrete
missing API is established; this does not yet prove the cause or correction
of a particular clipped command card.

Source contract reviewed in Gen1Recomp `535a5ec0`, `src/core/Game2.lua`.
The existing Chrome component retains its original provenance and licence
conditions. Original engine authors' rights remain effective. Integration
and tests by Roxas2712 are offered under
<https://github.com/Roxas2712/Gen2Recomped/blob/main/LICENSE-ROXAS2712.md>,
including its specific Cedric / UNDERdecoded permission with credit; this
does not replace earlier grants or assign ownership of the underlying engine.
