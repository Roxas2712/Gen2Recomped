# Native GBA trainer phazing

Ordinary Sapphire play against Shelly and Archie left Roar ineffective
against a player with healthy reserves. The shared Gen1 switch/Teleport
effect still refused all trainer replacements.

Adapt that builtin before mods capture it. Roar and Whirlwind use the GBA
rules; Teleport and other generations retain their existing callback.
Suction Cups and Ingrain precede accuracy. A trainer's shared double team
needs three able Pokémon; singles and separate trainer/ally parties need
two. The native lower-level check uses the low random byte. Replacement
selection samples all six (or a separate trainer's three) slots, rejecting
active, fainted, egg and empty slots without compacting the random pool.

The replacement stays in the targeted slot and party. Old stat stages,
confusion, Substitute and trapping links do not follow it. The outgoing
actor cannot perform an action after leaving; existing switch lifecycle,
entry abilities/items and experience observation remain in place.

Primary reference, pinned revision:
[pokeruby battle_script_commands.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/battle_script_commands.c),
`atk8F_forcerandomswitch` and `sub_80264C0`;
[BattleScript_EffectRoar](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/data/battle_scripts_1.s).

The CPU regression exercises all five GBA editions, both directions,
native random draws, refusals, shared doubles, separate-party ownership,
save isolation and cancelled outgoing actions. The native driver uses
prepared imported-trainer fixtures, original move records, ordinary menu
inputs and final-renderer captures for both directions and a double.
Prepared fixtures do not establish ordinary story completion or complete
forced-switch animation parity. No ROMs, saves or generated art are included.
