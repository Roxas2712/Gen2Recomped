# Original Emerald and FireRed/LeafGreen options

The generic five-row reconstruction now delegates to the exact Gen1Recomp
controllers at `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`. Emerald uses its
original window templates, palette, individual choices and twenty frames.
FireRed/LeafGreen retain their own seven-row view, small-font help bar and
ten frames. Labels and scroll artwork are extracted from the selected ROM.
No ROM-derived bytes are distributed.

The existing host fields, apply/save path and cancel callback remain authoritative.
Engine and mod options remain reachable through MORE OPTIONS. The small common
row bridge also serves the already-native Ruby/Sapphire options without changing
their pending-until-close behavior. Emerald/FRLG follow their reference controllers'
immediate option writes. Drawing never writes a save or changes host RNG.

Focused checks: `tests/engine/gba_native_options_readiness.lua`,
`tests/engine/rs_options_values.lua`, `tests/engine/rs_options_readiness.lua`.
Native acceptance: `tests/gba_native_options_driver.lua` in isolated Emerald,
FireRed and LeafGreen identities. Prepared fixtures exercise all six cartridge
enums, each frame, engine step/activation callbacks, scrolling, CANCEL, reopening
and the actual main-menu return. These fixtures are not complete story runs.

Control hints also require the selected cartridge's 128×32 keypad sheet.
The font's word fallback changes native control geometry and can collide with
Hall PC captions. Extraction and readiness now require that sheet for E/FRLG;
Emerald's private font context also receives its own FONT_SMALL masks and
widths. The original reference files remain byte-exact. The native options
fixture explicitly checks the icons and Emerald small face before capture.

Emerald native acceptance covers all six enums, the original twenty frames,
MORE OPTIONS step/action callbacks, scrolling, CANCEL, actual persistence,
reopening and main-menu return. Its twelve captures use the final renderer.
The fixture samples the title on the native canvas, host canvas and complete
window frame; original PNG pixel checks corroborate those results. Review
original-resolution captures when a reduced preview appears inconsistent.
This is UI acceptance with a prepared fixture, not a complete ordinary story.
FireRed/LeafGreen final native acceptance is still pending.
