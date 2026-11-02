# GBA rampage timing and presentation

The shared `THRASH_PETAL_DANCE_EFFECT` initialized two or three *remaining successful hits*, then decremented only after another hit. On GBA this produced three or four attacks, held the lock across missed rounds, and suppressed the animation/announcement of subsequent hits. It also confused the user during the attack rather than the original end-turn phase.

The GBA adapter initializes the original two/three-round duration and decrements it in the battler counter phase before Disable. Forced turns retain ordinary PP ownership and their complete attack presentation. Protect cancels the lock at its native pre-PP boundary; admission of an already selected zero-PP forced turn remains separate from the subsequent PP command. Fatigue respects existing confusion and Own Tempo, and native Persim/Lum handling stays in the item schedule. Sleep/freeze infliction, flinch, Truant and infatuation release the affected lock. Earlier-generation records keep their existing behavior.

Type immunity and confusion self-damage retain their lock until `WasUnableToUseMove` in the original end-turn phase, where they cancel without new fatigue. Full paralysis cancels immediately in Ruby/Sapphire; FireRed/LeafGreen/Emerald defer this cancellation to that phase. The existing shared volatile cleanup preserves only this pending GBA rampage until its owner releases it.

The high PP use against Phoebe in the ordinary Emerald trace was also inspected: Dusclops's Pressure and consecutive Protects explain the repeated initial charges. That observation alone was not treated as a PP bug. A subsequent native ordinary-input fixture independently exposed another debit: the native planner wraps forced actions, while the old PP continuation check compared action-table identity. GBA rampage now follows the locked move and its actual learned-slot owner through these wrappers. A separately selected slot cannot borrow that continuation exception. The regression goes through the real planner before testing both its free continuation and Protect-canceled debit.

Original semantic references (no cartridge data or decompilation source files are distributed here):

- [Emerald battle scripts](https://github.com/pret/pokeemerald/blob/731ad5bfd6e6f265508d0efcca0ba42f9dcf5881/data/battle_scripts_1.s): `BattleScript_EffectRampage`.
- [Emerald script commands](https://github.com/pret/pokeemerald/blob/731ad5bfd6e6f265508d0efcca0ba42f9dcf5881/src/battle_script_commands.c): Protect in `Cmd_attackcanceler`, `MOVE_EFFECT_THRASH`, confusion immunity and `Cmd_confuseifrepeatingattackends`.
- [Emerald battle utilities](https://github.com/pret/pokeemerald/blob/731ad5bfd6e6f265508d0efcca0ba42f9dcf5881/src/battle_util.c): `ENDTURN_THRASH`, `WasUnableToUseMove`, `CancelMultiTurnMoves`.
- Ruby/Sapphire revision `5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f`; FireRed/LeafGreen revision `ce6406d8c2eaf46d543c8a2606de0c3cb1951982` carry the corresponding script and counter phases.

Validation status: five-edition engine cases are prepared in `tests/engine/gen3_rampage.lua`. `tests/gen3_rampage_native_driver.lua` selects the imported Outrage through ordinary battle input, observes both native duration rolls through their actual end-turn schedule, and captures every continuation's original animation in the final renderer. It checks selected PP, fatigue timing, decision-menu return and draw immutability. These prepared battles retain imported species statistics and use a harmless imported opponent move. Local runtime tests and final-renderer qualification remain pending while the previously coordinated external test window runs. No ordinary campaign completion is claimed by these fixtures.

Contributions by Roxas2712 follow `LICENSE-ROXAS2712.md`. Existing upstream and third-party rights remain unchanged.
