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
