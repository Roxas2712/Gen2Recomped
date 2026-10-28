# Native Ruby/Sapphire Hall of Fame presentation

Ruby and Sapphire previously showed one stationary Pokémon at a time in a
generic Hoenn panel, followed by a text-only player panel. The native
presentation now flies in the actual team, dims prior members, plays cries,
shows the full team with confetti and applause, reveals the correct player
portrait and native name/ID/time panel, then waits for A before the native
credits. One-to-three-member teams use their separate native positions.

Four additional byte-exact files from Gen1Recomp
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b` retain their original license and
individual hashes in `compat/gen1-rs/provenance.json`. The reference inventory
contains 189 files. Graphics, palettes, portraits and original RS labels are
decoded from the verified local cartridge. `rs-native-hall-v1` invalidates
only old RS imports; readiness checks require all resources and labels.

The reference receives temporary numeric views of the original party. The
host's stable species IDs, personality, shiny state, nickname and OT stay
authoritative. Normal portraits retain the public sprite hook with kind
`hof`; eggs use the original RS egg picture already imported for summary.
Reference RNG remains private. Draws preserve save data and gameplay RNG.

The existing GameClear owner still grants ribbons, heals the party and
records the induction. The presentation uses `dontSave`, `warp=false` and
its host callback, so it cannot perform a second induction/save through
numeric aliases. Native save/title flow and durable team-history storage
remain separate work; this change is presentation acceptance.

The readiness regression passes 78 assertions; related credits, boot and
ending-import suites pass another 112. Prepared native tests on
`72e43d6b3e78240ca1b011d62a238e83023f7e94` passed fresh full imports in both
editions with all six party members, confetti, the player panel, all 52
credits pages, five cycling scenes, 68 Pokémon slides, THE END/music,
ordinary ending input and resumed script. Fifteen final-renderer captures
per edition check draw-time save/RNG immutability. Ruby used the girl and
Sapphire the boy; these fixtures are not ordinary story playthroughs.

`tests/rs_hall_small_native_driver.lua` separately covers one- and
three-member layouts, an egg's actual image, unchanged party values and
the correct handoff into credits. It explicitly tears down those prepared
fixtures after the credits start and does not claim another complete roll.
Both edition fixtures passed on `47e4dd6956a473229349e37085fe3fc9c11f71cb`,
including opposite player genders to the six-member tests, with eight
captures each. The egg uses the already imported native egg asset rather
than exposing the unhatched species. The final head adds documentation only.
Cartridges, generated assets, saves and captures remain private.
