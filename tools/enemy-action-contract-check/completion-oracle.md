# Cartridge faint and Spit Up completion expectations

The clean reference at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`
retains a sleeping caller's major status in the `user_faint` post-hit fixture,
and its Spit Up set-damage path omits the Wonder Guard test. The current host
implements the cartridge commands in both cases. These differences surfaced
in the broader integration's CI, independently of the RS credits code.

Primary implementations are [FireRed](https://github.com/pret/pokefirered/blob/master/src/battle_script_commands.c)
and [Emerald](https://github.com/pret/pokeemerald/blob/master/src/battle_script_commands.c):
`Cmd_cleareffectsonfaint` clears major status before the controller update.
`Cmd_typecalc` rejects neutral damage against Wonder Guard for a damaging
move. [Spit Up's script](https://github.com/pret/pokeemerald/blob/master/data/battle_scripts_1.s)
executes `stockpiletobasedamage`, `typecalc`, then `adjustsetdamage`;
its [move metadata](https://github.com/pret/pokeemerald/blob/master/src/data/battle_moves.h)
has nonzero power (100). Stockpile consumption and PP occur before the guard.

`cartridge_completion.py` builds explicit expected rows from the raw pinned
reference. Only the fainted battler's major status in `user_faint`, and the
neutral Wonder Guard hit/amount in Spit Up's three nonzero stockpile cases,
are corrected. Live battlers, PP, move events, other damage, hook calls,
stockpile consumption and RNG remain subject to the complete strict comparison.
Unknown corrected-state shapes fail instead of being ignored. Both originals,
the `equal` result, the cartridge `accepted` result and every corrected row
remain in the report. The read-only reference and production code are unchanged.
