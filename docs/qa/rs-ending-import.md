# Ruby/Sapphire ending-resource admission

The imported RS dataset omitted both the Hall of Fame and credits. The Hall of
Fame search required Emerald's exact `NAME` label; RS prints `NAME /` from its
own `gOtherText_Name`. Its credits records have one byte plus padding before
the text pointer, whereas Emerald adds an `isTitle` byte. Applying Emerald's
minimum heading count rejected RS's complete original page table.

The Hall of Fame matcher now admits the edition's exact original label. RS
credits retain the existing readable-name density, record extent and closed
five-row page-table checks without requiring Emerald's additional title byte.
Emerald and FRLG retain their existing admission rules. Existing renderer,
ceremony and credits callbacks are reused.

Primary RS references, pinned to
`5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f`:

- [Hall of Fame player information](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/hall_of_fame.c):
  `HallOfFame_PrintPlayerInfo` prints the original name label.
- [Credits records and page rendering](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/credits.c):
  `struct CreditsEntry`, `gCreditsEntryPointerTable` and five centred rows.

`tests/engine/rs_hall_of_fame_text.lua` uses owned synthetic bytes through the
actual text decoder and pointer-table parser. It checks exact edition labels,
missing and unrelated text, record runs without page tables, repeated page
pointers, and Emerald isolation. The pre-fix Hall of Fame cases failed six
assertions; the combined corrected contracts pass 33 assertions.

`tests/rs_ending_native_driver.lua` is a prepared imported-ROM fixture using
the actual GameClear special, two Pokémon, original player label, welcome,
52-page credit roll, edition music and script continuation. It checks final
renderer captures and draw-time save/RNG immutability. It does not constitute
an ordinary Champion win.

This change restores missing resource admission. The existing generic Hoenn
ceremony/credit renderer still has presentation differences from the cartridge,
including the animated cycling scenery; complete ending parity remains open.
Private ROMs, saves and traces are excluded from the public change.
