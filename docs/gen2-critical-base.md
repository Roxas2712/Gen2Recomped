# Native Gen-2 critical base

Gen-2 critical hits double the truncated base damage before the damage cap
and final +2. Using Gen-1's doubled-level calculation instead changes the
rounding at levels such as 1, 3 and 29. At level 29, power 35 and equal
50-point Attack/Defense, a non-STAB critical at random 217 deals **17 HP**;
the doubled-level path dealt 16. With STAB the result is **25 HP**, not 23.

Imported `constants.generation = 2` now selects that native critical-base
step when the ruleset has no explicit critical multiplier. Gen-1's existing
level calculation and explicit-multiplier profiles retain their own paths.
This does not change critical probability or add another public mod API.

The same `examples/portable_critical_order` consumer now supports Gen 2 as
well as Gen 3. It forces or suppresses `battle.crit` using only the public hook.
The Gen-2 contract cases run actual native move pipelines through both real
SDKs on Gold/Silver/Crystal: both attackers, levels 1/3/29/30/99/100,
critical/noncritical, STAB/non-STAB, and random rolls 217/255. Damage, PP and
public callback counts are compared. Stats, active types and generation
metadata are explicitly equivalent; neither native damage function is mocked.

The existing FireRed/Emerald matrix also remains in the shared checker.
See [the combined critical checker](../tools/critical-order-contract-check/README.md)
and [the earlier GBA correction](gen3-critical-order.md).

These tests establish the covered critical-base rounding. Further Gen-2
modifiers, stage/badge interactions and full battle-rule parity require their
own validation. Callback context equivalence beyond what the shared public
consumer reads is not asserted by this damage matrix.

For native LÖVE, install the example in an isolated imported Gold identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/gen2_critical_base.lua \
  bash scripts/run-portability-test.sh
```

The driver starts New Game in memory and constructs six battles with controlled
session stats. Actual FIGHT/move input and complete turn queues check ordinary
hits, critical level boundaries and STAB through the public consumer. It stops
before battle finish, afterBattle or normal SAVE. This is not a complete
playthrough or fresh full-ROM import; native Silver/Crystal GUI runs are not
implied by the headless matrix.
