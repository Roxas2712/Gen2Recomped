# GBA player battle tonics

X Special previously reached the shared Gen1 `special` stage (also affecting
Special Defense through its fallback). X Accuracy enabled Gen1's never-miss
bit. Saturated stats, repeated Dire Hit and Guard Spec also used older item
consumption rules, and Guard Spec did not own the native expiring side timer.

The player BAG path now executes the imported effect bytes for these seven
native tonics. Attack, Defense, Speed, Special Attack and Accuracy are separate
stages. An already saturated stage or active Focus Energy/Mist refuses the
item without consumption, a turn or friendship. Guard Spec shares the existing
five-turn side condition with Mist, including the partner in doubles. The
current menu controller owns the recipient. Successful effects apply only the
friendship bands present in the cartridge record, with native held-item,
Luxury Ball and birthplace additions. Gen1 retains its original X Accuracy.

Independent policy reference: `PokemonUseItemEffects` and the tonic effect
table in pret/pokefirered revision
`ce6406d8c2eaf46d543c8a2606de0c3cb1951982`, with the same native byte fields
in the imported Ruby, Sapphire, Emerald, FireRed and LeafGreen records. No
cartridge content or reference C implementation is distributed by this change.
Existing engine authors' rights and licences remain effective; contributions
by Roxas2712 are governed by `NOTICE.md` and `LICENSE-ROXAS2712.md`.

`tests/engine/gen3_player_battle_items.lua` covers all seven programs in all
five GBA editions, failure immutability, separate Special Defense, the double
menu recipient, friendship bands/bonuses and a Gen1 control.
`tests/gen3_player_battle_items_native_driver.lua` is explicitly a prepared
fixture: each edition imports its own records, uses ordinary BAG/A inputs,
checks actual consumption and turn advancement/refusal, and captures the final
renderer while checking draw-time SAVE/RNG immutability. It is not a normal
campaign completion test. Native execution and CI must be recorded after they
actually finish.

The ordinary story driver also reports an unchanged-turn move-menu refusal
accurately and exports existing Torment/Disable/Encore/Taunt state read-only.
These observations do not change battle state or admission rules.
