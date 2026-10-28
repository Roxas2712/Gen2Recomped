# Native touch hotbar

The native default pad now exposes Gen1's SAVE/LOAD/SPEED/COLOR/TILT/ZOOM
strip and its public hotbar geometry/control APIs. The cells dispatch the
actual engine keyboard owner; they do not implement a separate save system,
palette, camera or speed clock. Key `1` now reaches the guarded native speed
ladder, shared with custom-skin toggle actions.

Native Gen4 controls and shoulder positions remain in their existing owner.
The toggle starts between the shoulders. Portrait/landscape positions and
scale use the existing touch editor, whose chrome clears the center toggle.
The strip fits the window safe area and opens above a bottom-positioned
toggle. Preview cannot activate invisible hotbar cells. Mobile/forced-touch
OPTIONS includes a persistent HOTBAR ON/OFF preference.

A pad-owned gesture remains owned until release even if its synchronous
keyboard action resets the touch controller or opens another screen. Ended
touch IDs are polled away; the touch list cannot cancel an actual mouse hold.
Gen2 speed gating consults the actual persistent world beneath an empty
overlay stack, including scripts, emotes and engagement.

## Evidence

Tested source `a71a1515f824fb9cfcda33cf7a7cbb83d797b629`, including fork main
`a9227f308cfd9ee9c30c2e1a7b22c935a3fafca8`:

- Copied/adapted Gen1 hotbar contract: 51 checks. Native integration: 273
  checks. Actual F1 writes a captured snapshot through SaveData into a memory
  filesystem; F2 reads that format back into the continuation admission
  callback. This unit does not claim full story restoration or real OS IO.
- SPEED/COLOR/TILT/ZOOM change actual native owners and persist their options.
  Native fixed-speed/link/script gates, mod pointer first refusal, synchronous
  pad reset, contact-ID recovery, notch offsets, rotations, scale limits,
  normal OPTIONS input and actual editor drag are exercised.
- Negative control `45119d10`, using the final native fixture, fails exactly
  four script/engagement/emote speed-gate assertions. Corrected source passes.
- Real LÖVE 12 on Apple M3: Metal 2.1 and OpenGL 4.1 each pass 14 Gen1/native
  GPU strip comparisons, portrait/landscape times open/six pressed states.
  All six key press/release edges and restored release pixels are verified.
  Equal user-selected toggle geometry is used for pixel comparison because
  the native default retains its own shoulder/Gen4 layout. Native assets and
  real fonts are used; full native portrait/open and landscape/pressed images
  were inspected. This is offscreen framebuffer evidence, not OS input,
  device vibration, full-mod playability, performance or release acceptance.
- Focused haptics37, custom skins59, native speed clock408, viewport56 and
  orientation12 regression contracts pass on the composed source.

The hotbar remains an increment toward full parity. SkinStudio/library editor,
complete unchanged-mod scenarios and packaged release qualification are open.

## Provenance

The identified hotbar geometry/drawing and copied test originate in
Gen1Recomp `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, Copyright (C) 2026
BOIS CLUB GAMES, LLC. GPLv3 and Section 7 terms are retained in
`licenses/GEN1RECOMP-TOUCH-SKINS.md`; native integration contributions by
Roxas2712 remain subject to those grants and `LICENSE-ROXAS2712.md`.
