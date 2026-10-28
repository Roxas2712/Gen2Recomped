# Native frame widgets

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

The existing Font user, standard, dialogue and signpost helpers offer `frame`
contexts to the native presentation provider. Pixel bounds come from the same
native record/cap rules used by actual painting, including old caches without
dialogue/sign artwork. The source tile-template helper borrows the native standard
frame rather than the user-selected frame. No new controller, atlas or draw clock
is introduced.

A provider handles the decoration or falls back to the native helper. Repeated
base requests borrow one paint; native helper-to-helper fallbacks remain native
and cannot recursively re-enter the provider. Native failures remain fatal even
when caught by a decorator. Base return tuples and the native font's colour/font
postconditions survive provider isolation, both inside a base caller and before
the next ordinary label. Provider canvas/scissor/stack changes remain fenced.

`frameWidgets` is now advertised alongside `nativeUiStack` and `windowLayers`.
The complete PC/bag/naming/summary/battle theme families remain gated. Frames
without an admitted provider, and all other generations, keep their native bodies
without creating frame contexts.

Frozen fork `5cb5cc460c` passes 62 CPU groups, including 657 frame/provider checks;
independent older-public composition `fd7c59ce81` passes 33 groups with the same
657 checks. Fork GPU `de618dc80c` and public GPU `e710c2c5d9` each pass 4,322 checks
across 480 frames on both Metal and OpenGL. Owned asymmetric frame strips and the
following native label compare against ordinary native output: five editions,
all four frame kinds, imported/fallback artwork, DPI 1/2, scale 1/2 and false,
borrowed-base and failed-provider paths. These synthetic pixel checks do not
establish complete themed-family, cartridge-art, full-game, window or sustained
performance acceptance. QA keeps isolated profiles and at least 20 GiB free;
player saves and private runtime files remain untouched.
