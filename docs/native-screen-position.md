# Native screen positioning

The source Gen1/Gen2 option `screenPos` selects CENTER, UPPER or TOP. The
fork listed that key in its Gen2 video group but had no descriptor, runtime
module or compositor application. Add the actual option, apply it on load,
and keep the default CENTER geometry.

`ScreenPosition` retains the source normalization/cycling/lift contract.
The native renderer applies the lift in whole framebuffer pixels, converts
it using its actual vertical DPI, and shares the result between world and
UI origins. The world canvas grows below the raised camera to keep covering
the window. Source Game2 drawable queries and native Gold menu queries
observe the same positioned rectangle. Safe-area top insets bound the lift;
active touch-skin and native split-screen owners keep their own origin.
Selecting a position while a skin owns the viewport leaves the stored
selection intact and displays SKIN.

The source helper is adapted from Gen1Recomp revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, copyright BOIS CLUB GAMES, LLC,
under the retained GPLv3/Section 7 terms in
`licenses/GEN1RECOMP-TOUCH-SKINS.md`. Native integration by Roxas2712 retains
those terms. No mod, protected Gen1 install or player profile is changed.

Implementation `f137c679` passes 1,145 selected contract checks across eight
editions, portrait/landscape/Retina sizes, all three positions, safe insets,
the actual skin parser, source queries and native option input/save/boot
application. Existing frame-query 4,454, chrome 116, viewport 56, skin 59,
playfield 585 and battle-window 315 checks also pass. The extended probe on committed source `35ca1197` passes all 1,151 checks,
including actual final native world/UI blits and retained window coverage.
Both managed test hosts are cleaned after successful exit.

Exact head `a6eb0c05` independently passes944/944 engine suites,4/4 SDK
suites and all available official ROM-free tiers. All77 latest exact-head
CI checks succeeded or were skipped. The macOS transport timeout passed on
one rerun of the identical head, without changing its limits or tests.
PR351 is merged as `25c0b749`; its tree is identical to the qualified tree.
Actual GPU/window acceptance, every custom skin/device and final release
qualification remain open. The older upstream
adaptation is prepared against its actual `Renderer:endFrame` and flat
options menu, without adding the newer fork's `frameRects` or grouped-menu
methods. Its independent selected qualification passes 1,031 position checks,
4,454 frame-query checks and 116 chrome checks; see upstream PR398. These
proofs do not establish GPU or complete older-host qualification.
