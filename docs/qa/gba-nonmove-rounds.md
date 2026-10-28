# GBA round start after BAG actions

An ordinary Sapphire Elite Four run exposed unchanged `turnCount` after
FULL HEAL and HYPER POTION, even though the enemy action and residuals ran.
The common non-move entry skipped the initialization used by move rounds.
That left Protect/Endure and previous damage state active and allowed Fake
Out after an initial item round.

Both entries now share native order preparation and round initialization.
Enemy selection still precedes cleanup, preserving the previous-round AI
inputs and the existing shared random word. Committed native item, switch
and escape actions advance the round once; opening/cancelling BAG and a
trainer RUN refusal do not. Older generations retain their existing
non-move ownership. GBA battle fingerprint revision 27 prevents old/new
simulations from negotiating identical battle rules.

Source contract: [pokeruby battle_main.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/battle_main.c),
`BattleTurnPassed` and `TurnValuesCleanUp`, retire protection and the
first-turn window independently of whether the chosen action was a move.

The ROM-free regression failed 80 of its initial 124 assertions before the
fix. Expanded coverage passes 184 assertions across Ruby, Sapphire,
Emerald, FireRed and LeafGreen: expired protection, stale damage/Helping
Hand/Follow Me, consecutive item replies, legal and illegal Fake Out,
ordinary switching, failed escape, refusal and generation isolation.
Related order, Rage, Choice Band and Follow Me suites pass 17,764 assertions.

`tests/gba_nonmove_native_driver.lua` prepares its own combatants and uses
the real Protect, BAG, Potion, party-target and Fake Out controls over
imported cartridge data. It checks exact item/PP consumption, the enemy
reply, round counts and final-renderer save/RNG immutability. These are
prepared battle fixtures, not ordinary story or full-game acceptance.
Cartridges, generated art/audio, screenshots and saves remain private.

Native fixtures passed in all five editions on runtime
`cd9401be7064d72af5189da23eca6d4d0d884726` (the later head changes only
documentation and protocol expectations), with three captures each. The
ordinary Sapphire Drake fight also witnessed HYPER POTION advancing round
5 to 6 and one Salamence reply before the battle was won. Protocol tests
retain fixed audited digests and reject both previous command revisions
26, 23 and 22, symmetrically, through the actual link controller.

Current-main integration retains command revision 26 features and advertises
revision 27. Independent integer FNV auditing yields `78dbbb41ed15c325`
(FireRed/LeafGreen/Ruby/Sapphire) and `fb32852c3ce04be0` (Emerald);
legacy and NDS digests remain unchanged. Native fixture results above belong
to the stated earlier component runtime; current integration qualification
is recorded separately and does not imply a new graphical story test.
