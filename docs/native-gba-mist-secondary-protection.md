# Mist and guaranteed secondary effects

Ordinary GBA secondary stat changes keep Mist and ability protection even when
their configured probability is 100 or greater. Probability does not grant the
separate cannot-prevent flag. `SetMoveEffect` calls `ChangeStatBuffs` with only
the affected-user flags for stat effects; that function checks Mist, Clear
Body, White Smoke, Keen Eye and Hyper Cutter. See the original command paths in
[FireRed](https://github.com/pret/pokefirered/blob/master/src/battle_script_commands.c)
and [Emerald](https://github.com/pret/pokeemerald/blob/master/src/battle_script_commands.c).

The frozen Gen1 reference `535a5ec0` instead forwards probability >=100 as its
`certain` flag to its stat helper. The shared Mist fixture records the resulting
known difference explicitly: a Bubble edited to 100% lowers speed through Mist
on that reference, while the native controller retains protection. Self changes
and the side condition's actual five-turn expiry remain separately exercised.
The reference engine is read-only and is not changed by this PR.

`gen3_secondary_protection.lua` checks chance boundaries, protections, self
changes and the actual native Mist owner. `gen3_mist.lua` exercises real moves,
Guard Spec, switching, both flanks, Haze, Intimidate and expiry. The comparison
tool retains `equal: false` and `full_parity: false` for the known reference
difference. Only the exact labelled speed transition -1 to 0 is classified;
other field changes, reversed transitions, missing rows or other effect families
fail. A complete five-edition/three-mode Mist run has 15 visible reference
differences, rather than a claim of complete Gen1 battle parity.

Contributions by Roxas2712. Existing rights and notices remain in effect.
