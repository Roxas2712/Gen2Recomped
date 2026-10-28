# Native Ruby/Sapphire credits

The Hoenn ending previously displayed staff names on black, with a fixed
page timer and a START skip. Ruby and Sapphire now use the pinned native
credits controller: five cycling scenes, the caught-Pokémon slides,
original page transitions/palettes/font, THE END and its own music/input.
The host still owns completion and the return callback.

Four additional Gen1Recomp files are retained byte-for-byte from
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b`, separately hashed in
`compat/gen1-rs/provenance.json`. Their original GPLv3 license and additional
terms remain in `reference/LICENSE.MD`. No reference files are rewritten.
The adapter supplies temporary numeric species, gender, starter and caught
views over stable host IDs. Images, palettes and all 52 five-entry pages
are decoded locally from the selected verified cartridge. Nothing derived
from a cartridge is included in the public source.

`rs-native-credits-v1` requires new Ruby/Sapphire imports. Positive readiness
checks cover every page and all seven credits resources; damaged, incomplete
or other-edition caches are rejected. Other editions retain their own
credits implementation and cache revisions. Presentation RNG stays in the
isolated reference context, with no persistent conversion of host save data.

The ROM-free readiness regression passes 62 assertions. Related boot and
ending-import regressions pass 50. The prepared native ending driver runs
the actual GameClear special, Hall of Fame, all 52 native pages, five bike
scenes, 68 Pokémon slides, THE END music, ordinary final input and resumed
script. It records eleven final-renderer captures and checks draw-time
save/RNG immutability. Both Ruby and Sapphire passed on component runtime
`bf807e5a4362d0030a91d297406b1c34a1a0c717`. Fresh full imports and the same
complete native checks also passed on integrated runtime
`7fcf9e76367b806a88105d235e86da2cec773bcf`, based on public main
`87b90834558c8dfced863bd45aa5c93ce79edfaa`. Subsequent changes add documentation
and CI comparison expectations without changing that runtime. Five focused integrated contract groups pass 690 assertions, including
the current native battle revision 27 and the existing item-round regression.

This is credits presentation acceptance in prepared fixtures. The ordinary
Sapphire story test reached its first Champion win, Hall of Fame, complete
previous credits, home SAVE and unchanged CONTINUE before this change.
It is not a replay of the story with the new movie. Hoenn Hall of Fame
fly-in/confetti/player portrait, the native ending save/title flow, Emerald's
movie and the other games' full-story coverage remain separate work.

The integrated CI matrix also exposes two older reference gaps outside credits:
major status after a caller faints, and neutral Spit Up against Wonder Guard.
The documented cartridge completion oracle keeps complete comparisons while
correcting those exact expectations. Rechecking all raw failed CI rows against
the original commands accepts both editions: 120 faint rows and 24 Spit Up rows
per edition. Fifteen oracle unit tests cover the original secondary rules,
these corrections, retained raw reporting and rejection of unrelated drift.
This does not claim equality with the older reference bugs.
