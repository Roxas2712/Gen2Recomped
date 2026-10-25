# RetroRecomped library shell

The implementation starts from the fork's `main` at `13af468b` on
`codex/retro-launcher-layout`. The Gen1 launcher's immediate-mode menu structure
was inspected as a usability reference; this shell adds its own layout,
hardware illustrations, editor and intro sequence.

## Behavior

- The library opens first. Console, imported-game and favorite filters compose
  in place. Opening a cartridge and pressing Back returns directly to the library.
- System cards show the corresponding handheld silhouette. The **LOGO CARDS**
  checkbox switches between hardware cartridges and RetroRecomped-logo cards.
  It persists independently of custom designs.
- Tools are grouped by saves, customization and library management. Settings
  opens a category hub, with **All settings** retaining the full original list.
- Game details put Play beside the cartridge, followed by save management.
- Cartridge Studio offers label text, shell/label colors, arbitrary RGB hex,
  three emblems and custom PNG/JPEG artwork. It saves one visual design per
  registered game in application options; it does not modify ROMs or saves.
  The saved design is also used by the launch animation.
- Artwork is decoded to PNG, limited to 8 MB input and 2048 x 2048 pixels.
  Stored paths are confined to `launcher/cart_art/`. A failed preference write
  leaves the previous saved design intact.
- The six-second startup has converging lightning, a synthesized guitar
  arrangement of the short opening IntroBattle figure, and a logo that docks
  into the header. Audio follows Music Volume and stops immediately on skip.
  The entire sequence can be skipped or disabled in Launcher settings.
- Play arcs the cartridge into the matching GB/GBC/GBA/DS silhouette and
  lights its screen before the original boot callback runs. Enter/tap skips;
  Escape/B cancels. Duplicate input cannot boot twice.

## Verification

Passing checks: 59 new pure Lua assertions, 58 existing scroll/touch/delete
assertions, and 26 live UI checks on each of LÖVE 11.5 and 12. The pure Lua
checks cover sequence lifecycle, category filtering, grid sizing,
design validation and hardware selection. The preview host exercises the real
RomImporter and normal mouse/key dispatch with a harmless boot callback, including
the logo checkbox, composable filters, settings navigation, RGB input, PNG
decode, design save/reload and cancellation. See `tools/launcher_library_preview`.

The PNGs are actual LÖVE renders, including 480-pixel portrait and short-window
cases. Sample readiness and the KRIS summary are fixtures, not a real playthrough.
`intro-preview.mp4` pairs deterministic rendered frames with the generated WAV.

The audio is synthesized locally; no recorded audio or soundfonts are bundled.
The short opening figure was checked against the local reference's
`audio/music/introbattle.asm` and its use in `engine/movie/intro.asm`.
`tools/build_launcher_riff.py` regenerates the WAV with NumPy.

Gameplay itself is not driven by the layout smoke host. Existing import, save,
mod and boot implementations remain responsible for those operations.
