# Native window and PP palette manifests

The chrome manifest exposes detached `textboxPal`, `windowTextPal` and
`ppTextPal` arrays from the active native dataset. Full palette validation and
RS edition tags prevent mixed or malformed metadata from reaching the font.
Replacing/mutating imported palettes is visible immediately, while mutations of
returned records cannot rewrite the native import.

The existing validated textbox stage retains its already decoded menu-palette
bytes. Emerald additionally reads the bounded sixteen-word `gPPTextPalette`
raw table, independently of the compressed window palette. FR/LG never read
Emerald's raw address. RS reuses its native panel/default-font records. The
three affected cache markers advance to `gba-textbox-palette-v2`, superseding
the earlier first-bank-only revision; other editions and save formats are
unchanged. Original resource provenance remains attached.

Fork source `f3a7211a9b` passes46 CPU groups. Public composition `f9ac06f6ce`
passes29. Both include108 new manifest/ownership checks and expanded extraction
checks covering raw PP bounds and palette separation. The unchanged-adapter
CPU audit with complete synthetic imported records also passes command, move,
target and message drawing for all five editions; synthetic records are not
cartridge visual acceptance.

Owned-output GPU runs `4b065a5ef2` (fork) and `2a44aeafe5` (public) each pass4044
checks across576 constructed frames on Metal and on OpenGL. In addition to
cursor density/effects and direct indexed text, the actual two-tone font is
checked through both window and PP manifest palettes for all five editions,
at DPI1/2. The owned fixture hash is recorded separately from the frozen CPU
source. No full-game, real-artwork, OS-window or sustained-FPS claim is made.
Managed QA retains20GiB free and does not access player profiles.
