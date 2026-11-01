# Original Emerald Wally tutorial

The ordinary Emerald campaign exposed a completed catching demonstration with
zero move turns. Emerald fell through the generic old-man demo because the
original Wally controller admitted only Ruby and Sapphire.

Emerald now uses the existing pinned RSE tutorial policy: two actual move
selections, withdrawal, trainer return and the scripted bag. Its text and four
Wally back frames come from the verified Emerald cartridge, with the original
Emerald back-table index and animation. The import readiness gate rejects an
older or incomplete tutorial cache without changing saved-game formats. Other
editions retain their own resources and controllers.

The tutorial uses the regular Emerald bag and item-action presenters. Virtual
Potion/Ball rows, the original visible CLOSE BAG row and USE/CANCEL labels do
not consume owned inventory. The 102-frame action delays pause during the
native pocket switch; open/close fades remain in the scripted timeline. Wally
uses male bag graphics for either player gender without changing the player.
The battle prompt also uses Emerald's own Wally text.

The source contracts are the original
[Wally controller](https://github.com/pret/pokeemerald/blob/master/src/battle_controller_wally.c)
and [scripted bag](https://github.com/pret/pokeemerald/blob/master/src/item_menu.c).
Pinned reference modules and their existing licences remain unchanged.

The guarded CPU checks cover edition isolation, cache readiness, the two
scripted moves, recall, virtual inventory and the real bag/pocket state
machines. The separate native driver independently decodes the user's ROM
pixels and original special pointers, captures final renderer views, checks
the female-player/male-bag case, and verifies party, inventory, player-name,
Pokédex and draw-time save/RNG preservation. Its prepared scene is not ordinary
campaign completion; continue the accepted first-badge campaign separately.

The critical-roll comparison uses synthetic level-30 battlers. Its host-side
Wally constructor probe isolates the presentation bridge, then checks the real
constructor's critical-exclusion metadata. It does not pretend to supply the
original borrowed Zigzagoon or ROM art. The dedicated tutorial contracts and
native scene above exercise those strict requirements separately.
