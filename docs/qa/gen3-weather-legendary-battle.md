# Weather legendary battle start

Ordinary Sapphire play reached the Blue Orb scene in the Cave of Origin,
but canonical special 313 was unserved. The VM skipped the prepared Kyogre
battle and wrote the story completion flags. This is a failed ordinary
encounter, not accepted story completion.

Serve `StartGroudonKyogreBattle` through the existing legendary wild-battle
constructor. Ruby/Sapphire native special 311 imports as Emerald identity
313. Preserve the prepared species, level and item, use the ordinary
transition and legendary battle flag, and hold the script until its own
battle callback supplies the outcome.

Pinned primary sources:
[pokeruby battle_setup.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/battle_setup.c),
`ScrSpecial_StartGroudonKyogreBattle`;
[Cave of Origin B4F script](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/data/maps/CaveOfOrigin_B4F/scripts.inc).

The CPU regression runs the actual VM, battle constructors and completion
callback for Ruby, Sapphire and Emerald, covering win, catch, escape and
loss. The native driver uses a prepared field with actual imported species,
special dispatch, transition, battle introduction and final-renderer menu.
Neither fixture constitutes a completed ordinary legendary capture or
story. No ROMs, saves or generated art are included.
