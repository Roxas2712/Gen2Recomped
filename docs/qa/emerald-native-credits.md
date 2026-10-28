# Original Emerald credits

Emerald previously used the host's generic staff-text presentation. Its
verified cartridge now supplies the original 57 five-entry pages, five
cycling scenes, 71 caught-Pokémon slides, native Latin font, THE END and
ending music. The host retains completion, persistent species IDs and the
return callback. Emerald's existing generic Hall of Fame is unchanged.

Four additional reference files are retained byte-for-byte from Gen1Recomp
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b`, individually hashed in
`compat/gen1-rs/provenance.json`. Their original GPLv3/additional terms
remain intact. Cartridge-derived resources stay in local imports.

`emerald-native-credits-v1` invalidates old Emerald imports. Readiness checks
require all nine movie/font resources, every credit row, the original
512-glyph normal face and Emerald's own manifest identity. Both import and
playback bind the original RSE text dialect; FONT_1 must resolve to
FONT_NORMAL rather than FireRed's normal-copy face. Other editions retain
their cache revisions and controllers.

The shared Hoenn session adapter only supplies read-only numeric views of
host species, Pokédex flags, personality, gender and starter variables.
Rendering uses its private reference RNG and owned 240×160 canvas.

Verification on runtime `f5b4dd8dc310560f8e2d3bef7fbf3f14253a07e1` passes
after a fresh full Emerald import. The prepared native driver invokes the
actual GameClear special, advances the existing generic Hall with ordinary
input, then observes all 57 pages, five scenes and 71 slides, THE END music,
ordinary final input and the resumed host script. Seven final-renderer
captures and draw-time save/RNG checks pass. This fixture uses a prepared
female party and does not establish ordinary story or native Hall acceptance.

The ROM-free suites pass 235 assertions: 41 Emerald readiness/dialect,
132 shared session and 62 existing RS credits assertions. The shared session
refactor also passes complete fresh native Ruby and Sapphire ending runs on
`2817e8285dd967306df22ea114b4be5f78b4d884`: actual save failure/retry,
six-member native Hall, complete native movie, title and CONTINUE home,
21 final-renderer captures per edition and unchanged draw-time save/RNG.
Later runtime changes only bind Emerald's text dialect.
