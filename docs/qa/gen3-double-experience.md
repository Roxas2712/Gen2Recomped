# Independent experience participants in GBA doubles

Ordinary Sapphire play against Tate/Liza exposed a shared-mask error:
both players received 675 experience from the first opposing faint, but
the lead received 1350 and its partner received zero from the second.
The first award cleared the sole participant set, leaving the single-lead
fallback to handle the remaining opponent.

The original game keeps separate sent-in masks for the two opposing flanks.
Switching a player adds it to both occupied opponents; replacing one foe
resets only that foe's mask to the current player occupants. Experience
ignores fainted party members when calculating the divisor.

References:
- [pokeruby battle_util.c, ResetSentPokesToOpponentValue / sub_80157C4](https://github.com/pret/pokeruby/blob/master/src/battle_util.c)
- [pokeruby battle_script_commands.c, atk23_getexp](https://github.com/pret/pokeruby/blob/master/src/battle_script_commands.c)

`Gen3ExpParticipants` follows that lifetime using battle-local party indices.
The records survive logical checkpoints without retaining private object
references. The ordinary party scope and existing experience calculation,
held items, messages and rewards still decide the actual award. Other
generations and singles retain their existing participant path.

The focused regression runs all five GBA editions through actual battle
construction and repeated experience awards. It checks the second foe,
switching, replacements, faint/revive eligibility, record serialization,
party scopes and unchanged save/RNG during observation. Ordinary story
confirmation remains separate from these prepared fixtures.
