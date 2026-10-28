# Ruby/Sapphire battler positions

Ordinary Sapphire play against Tate/Liza showed both Pokémon on each side
at the same sprite anchor. Healthbox positions were present, but the sprite
coordinate stage still read Emerald's table, rejected it and left the
single/double rows absent. The renderer consequently used the single anchor
twice.

Read each edition's table through its own `GetBattlerSpriteCoord` literal:

| USA edition | Coordinate table | Reader | Checked pointer offset |
| --- | --- | --- | --- |
| Ruby | `0x37F578` | `0x077ABC` | `+0x64` |
| Sapphire | `0x37F508` | `0x077AC0` | `+0x64` |

The two rows contain four padded four-byte records each. Singles are
`(72,80), (176,40), (48,40), (112,80)`; doubles are
`(32,80), (200,40), (90,88), (152,32)`, in battler-position order.
The imported coordinates feed the existing renderer; healthboxes retain
their separate RS OAM anchors. A cache marker rebuilds older RS imports.

The original source names the table `gUnknown_0837F578` and reads its two
rows in `GetBattlerSpriteCoord`:
[pret/pokeruby, rom_8077ABC.c](https://github.com/pret/pokeruby/blob/master/src/rom_8077ABC.c).
Both ROM tables and reader literals were checked locally. No ROM bytes,
generated assets or saves are distributed.

`tests/engine/rs_battler_position_import.lua` checks native rows, the code
pointer, malformed padding and restoration of Emerald's stage parameters.
`tests/rs_battler_positions_native_driver.lua` uses prepared parties and
the imported Tate/Liza trainer, captures single/double battles and both
target choices, and checks the second battler's command/cancel path plus
draw-time save/RNG immutability. These fixtures do not establish complete
double-battle animation or story parity.
