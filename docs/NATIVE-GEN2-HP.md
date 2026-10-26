# Native Gen2 HP presentation

The shared battle engine resolves damage and queues the presentation of each
damage or healing beat. Gen2 now dispatches that actual queue row through
`BattleState:stepHpAnim()`, with `hpAnim.side` and `hpAnim.to` describing the
active beat. `shownHp.player` and `shownHp.enemy` read the real battlers'
displayed HP. Writes are admitted only inside that callback, for its actual
side and Pokemon, with finite values within the Pokemon's maximum HP.

The default callback retains the Gen1Recomp Gen2 implementation's 48-pixel
short/long loops, two-frame pixel cadence and high-HP integer division. A
decorator may choose different display increments for a wider HUD. The native
queue still waits for the actual target and retirement of `hpAnim`; returning
early cannot grant the next battle command. Display writes never mutate the
Pokemon's resolved HP. Queued multi-hit stops and battler switches preserve
their native owners. Gen1 and Gen3 retain their existing drain path.

`tests/engine/gen2_hp_presentation.lua` exercises the real shared battle class,
queue dispatch, multi-hit floors, healing, fainting, fractional display steps,
invalid writes, callback failure cleanup, battler replacement and the other
generations' unchanged path. These tests do not prove full mod playability,
move animation or capture rendering; those require separate implementation
and gameplay acceptance. This upstream contribution binds the HP view directly
in the native constructor; the fork's additional live battle-model and sprite
capture view is a separate integration. The HP regression stands on its own.

Pixel stepping adapts Gen1Recomp's `src/battle/gen2/HpBar.lua` and
`src/ui/gen2/BattleState.lua`. Existing upstream and Gen1Recomp rights and
credits remain applicable; see `NOTICE.md`. Native-owner integration and
regressions are contributions by Roxas2712, under `LICENSE-ROXAS2712.md` to the
extent of rights held.
