# Strength's selected Pokémon name

Ordinary Sapphire play in Seafloor Cavern displayed “used STRENGTH” with
an empty name. Rock Smash filled its name through its script; Strength's
script instead relies on its field-effect callback to populate STR_VAR_1.
The callback was omitted when the presentation was integrated.

Fill the transient first string buffer from the selected field-effect
party member before showing Strength's animation. Preserve the other
buffers, custom names, party/save contents, PP and continuation callbacks.
Other field effects retain their script-owned buffers.

The original `FldEff_UseStrength` calls `GetMonNickname` with
`gFieldEffectArguments[0]` and `gStringVar1` in all three engines:
[Ruby/Sapphire](https://github.com/pret/pokeruby/blob/master/src/fldeff_strength.c),
[Emerald](https://github.com/pret/pokeemerald/blob/master/src/fldeff_strength.c),
[FireRed/LeafGreen](https://github.com/pret/pokefirered/blob/master/src/fldeff_strength.c).

`gen3_strength_name_buffer.lua` checks all five editions, literal custom
names, default species labels, absent actors, callbacks, existing actor
fallback and save isolation. The RS native driver uses prepared fixtures,
the imported boulder script and ordinary inputs, captures both name forms
through the final renderer, then checks activation and a real boulder push.
These prepared fixtures are separate from ordinary story acceptance.
