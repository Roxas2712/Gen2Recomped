# Cartridge secondary-effect oracle

The read-only Gen1 reference at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`
has two known gaps in its secondary-effect helper:

- It uses an inclusive chance comparison for Emerald. Emerald's original
  command uses a strict comparison; RS and FR/LG use an inclusive comparison.
- It passes probability-derived certainty into stat-loss protection. A
  guaranteed opponent stat reduction still respects Mist and the relevant
  protective ability. Probability does not grant the stat command's separate
  cannot-prevent permission.

Primary implementations: [Ruby/Sapphire](https://github.com/pret/pokeruby/blob/master/src/battle_script_commands.c),
[FireRed/LeafGreen](https://github.com/pret/pokefirered/blob/master/src/battle_script_commands.c),
and [Emerald](https://github.com/pret/pokeemerald/blob/master/src/battle_script_commands.c).
See the chance command, `SetMoveEffect` and `ChangeStatBuffs` together.
The independent `tests/engine/gen3_secondary_protection.lua` suite checks
all 100 probability words and the applicable protection combinations.

For the two secondary matrix modes, `cartridge_secondary.py` constructs an
explicit corrected expected observation. Emerald's equality-boundary rows
use the same fixture's independent zero-chance/word-99 control for no-effect
state. Damage, Substitute HP and the actual damage/chance RNG draws remain
unchanged. Protected stat reductions retain stage zero and return failure.
Every field of the resulting observation is then compared strictly.

The report retains both raw backend observations, `equal` for the original
reference comparison, `accepted` for the cartridge oracle, and the exact
corrected rows. A successful cartridge correction does not claim byte-equal
reference behavior. Other modes keep the unmodified strict comparison.
Missing controls, duplicate rows, unexpected stat states, worker failures
and unrelated value/type changes remain failures. The checker never edits
the reference or replaces the runtime behavior with its older bugs.
