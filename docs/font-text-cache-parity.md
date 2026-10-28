# Font text selection and Gen1 parity

Repeated `Font.width` and `Font.draw` calls previously rebuilt glyph arrays
and UTF-8 spans even when the font and label were unchanged. Gen1's reference
renderer already reuses this work. The native renderer now keeps at most
4096 encoded labels and exposes the same `Font.glyphCount` and `Font.revision`
interfaces.

`Font.encode` still returns a fresh, caller-owned array. Widths are deliberately
measured through the current `advanceOf` function, preserving GBA proportional
faces and live face switches. A replaced public encoder is honored by width
and drawing; a replaced splitter bypasses the cache. `Font.load`/`invalidate`
retire cached selection, as does activation, replacement or removal of the
translation font. The missing-atlas draw path counts UTF-8 glyphs rather than
bytes when returning its width.

## Validation

- `luajit tests/engine/font_text_contract.lua`: 44 checks for UTF-8/ligatures,
  caller ownership, actual glyph dispatch and metrics, face switching, public
  hooks, reloads, translation activation/removal and missing-atlas fallback.
  On the previous `0af0b3cf` main, the same fixture fails on the missing
  `glyphCount` API. Its atlas/font I/O is synthetic; Font is the real module.
- A private comparison loaded the same owned Crystal font record and atlas
  dimensions into this renderer and frozen Gen1 reference `535a5ec0`.
  `split`, `encode`, width and glyph draw dispatch matched for all six sampled
  labels, including the single ROM tile for `é`. The earlier suspected
  encoding defect in `POKéMON` was not reproduced by this comparison.
- In a CPU-only sample, 2000 iterations of measuring and drawing six labels
  allocated 36142 KiB before the change and about 2.6 KiB afterwards, with
  identical checksums. Graphics calls were no-ops; this measures text
  processing and dispatch, **not GPU performance, frame rate or visual parity**.

No mod files change. This work does not supply Gen1's separate TTF font
configuration contract or qualify all fonts, menus or final release packages.
