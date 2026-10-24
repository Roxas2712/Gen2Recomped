# Enemy switch/item contract development

This branch is an in-progress implementation, not a published or fully validated
portability PR. It is based on published metadata prerequisite #173. The hook work itself
is not included in the combined testing branch until native decisions are ready.

Current source: clean Gen1Recomp `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
`tools/enemy-decision-contract-check/check.py` runs the unchanged public consumer
through both real SDKs in separate workers. The current matrix covers Red's
unavailable producer and Gold/Silver/Crystal/FireRed/Emerald native query paths.
It exercises explicit real healing and switches, suppression/true/nil,
repeat/claim/failing `next`, stock reservation, modifying a delegated item,
native HP thresholds/status cures and right-hand GBA double slots. This is not
yet proof of complete native battle/controller behavior.

The previously failing FireRed/Emerald automatic Perish Song switch now matches.
`EnemySwitch` implements native GBA automatic selection using host battlers and
imported type records: trap/ability gates, Perish Song, Wonder Guard, absorbers,
Natural Cure, immunity/resistance counters, positive stages and candidate
ranking/fallback. Decisions preserve the reference's RNG ranges, call order and
double-slot reservations. Execution can consume its own reservation; a new
explicit selection cannot select an already reserved slot.

The switch-policy milestone passed **12 workers / 219 paired observations** in each of
API 3 and host API 2/unified. Each GBA version includes **39** named automatic
policy cases, a two-query double reservation and four actual native damaging
move/history cases. Real hits record landed move/attacker state; a Substitute
records the landed move without overwriting attacker state. Semi-invulnerability
and type immunity cannot invent hit history. A real Surf then drives the
ordinary resistance/counter decision, rather than supplying a fake hit record.
That milestone passed **317/317** focused checks. This remains bounded query,
effect and execution evidence, not complete native battle/controller parity.
The complete development run passes **139/149** engine suites, **3/3** SDK
suites and B30. Its **26** failure lines across ten baseline suites exactly
match the earlier development baseline; no new failure lines were introduced.
Logs/reports are retained under `tmp/enemy-switch-item-qa/` as
`full-switch-policy.log`, `targeted-switch-history.log`,
`contracts-switch-history.json` and `contracts-switch-history-api2.json`.

## Raw GBA trainer item milestone

`EnemyItems` now selects and applies #173's actual imported effect bytes. Its
stock compacts only the first four native slots, preserves duplicate slots,
keeps the initial stock count and reserves a slot during selection. It applies
raw HP sentinels, selective status/confusion/infatuation cures, Focus Energy,
all native X-stat nibbles and side-owned five-turn Mist to the chosen enemy,
including the right double slot. Native Mist moves share that side timer and
prevent wasting Guard Spec. A fainted explicit revive remains executable;
ordinary moves retain their live-user/target gates.

The cartridge's `GetItemEffectParamOffset` returns the first argument for a
HEAL_HP request even when EV bits precede the heal bit. Trainer selection and
application preserve this behavior rather than using the parsed field-medicine
amount. See the [native FireRed implementation](https://github.com/pret/pokefirered/blob/master/src/pokemon.c#L4641).
Tests cover both refusal at the native raw threshold and actual healing with
that first argument. A changed item display name cannot change its native type;
an unchanged delegated item retains its physical key even when aliases exist.

The current matrix passes **12 workers / 333 paired observations** in each of
API 3 and host API 2/unified. Each GBA version adds **45** raw-item cases, alias
resolution, duplicate/egg/initial-stock boundaries, shared double stock, native
Mist move/item interaction and six native Mist lifetime/partner-stat-drop
observations. Host checks pass **907/907**, including old parsed-medicine
caches, refusal of missing battle-only bytes and truncated healing parameters.
Old caches must be reimported for the additional raw battle effects; missing
bits are not inferred from item names. These remain native query/effect/residual
tests with importer-shaped records, not a fresh full-ROM import or complete
ordinary controller/gameplay validation.

Current reports: `contracts-raw-items.json`, `contracts-raw-items-api2.json`,
`targeted-raw-items.log`, and `full-raw-items.log` in the same QA directory.
The complete raw-item run passes **139/149** engine suites, **3/3** SDK suites
and B30. Its **26** failure lines are exactly unchanged from the switch-policy
milestone's ten baseline suites. The combined testing branch remains separate
and does not include this unfinished hook implementation.

The implementation preserves Gen 2's imperative boolean query and GBA's
deferred action/stock-consumption contract. The public callback receives the
original battle handle, as in the reference. Native automatic selection and
presentation are still being audited; passing the current matrix is not a
claim of full AI or battle parity.

## Ordinary controller milestone

The same public consumer now runs through the reference's public GBA battle
module startup/update and the host's real trainer constructor, turn planner
and presentation queue. Twelve ordinary-turn cases per FireRed/Emerald compare
complete HP/stage/stock observations and event order. They cover item priority,
constructor stock freezing, lethal-hit prevention, suppression/replay/recovery,
explicit/automatic switches and both double-slot first-turn decisions. Six
additional native command-producer gates cover wild, tutorial, locked and
recharge cases. Fixture species types, move records and session stats are
explicitly equivalent; final HP values are not filtered from comparisons.

The host snapshots native GBA stock at construction, queries both enemy slots
before advancing first-turn ages and resolves queued attacks against the live
slot occupant after a switch. Gen-2 trainer stock is copied per battle without
mutating the imported class definition; thirteen constructor/rematch checks
pass for each of Gold, Silver and Crystal.

Focused checks pass **1,046/1,046**. Both API 3 and host API 2/unified pass
**12 workers / 369 paired observations**, with zero differences. Running these
same tests against the previous engine commit `9671c57` produces eight actual
GBA assertion failures and three Gen-2 stock/rematch failures, demonstrating
that the checks detect the corrected behavior. The temporary parent checkout
was clean; these are negative controls, not current failures.

The complete run still passes **139/149** engine suites, **3/3** SDK suites
and B30. All **26** failure lines exactly match the ten baseline suites.
Reports are `contracts-native-turns.json`, `contracts-native-turns-api2.json`,
`targeted-native-turns.log`, `full-native-turns-final.log`,
`controller-parent-negative.log` and `controller-parent-gold-negative.log`.
These remain bounded synthetic-session controller checks, not fresh cartridge
imports, full Gen-2 ordinary-turn coverage or complete native battle parity.

## Imported-data native smoke milestone

The owned `portable_enemy_decision` consumer passes native LÖVE 11.5 smoke
runs on imported Gold, FireRed and Emerald data. The driver starts an isolated
New Game and uses the real FIGHT/move inputs, constructor and result queues.
It verifies suppression, an explicit Potion, replay, post-next error recovery,
stock isolation, incoming switch targets and unsubscribe. Species, moves,
items and artwork come from the existing imported caches; parties and trainer
stock are deliberately bounded in-memory test sessions. No normal SAVE action
or full-playthrough claim is made. Gold's old cache has no imported AI
attributes, so its delegated native decision is expected to remain inactive.

A separate FireRed run invokes the actual current item-effects importer on the
local cartridge, redirects its output to memory and uses those generated raw
bytes through ordinary turns. Potion, X Attack and Guard Spec pass, including
first-turn X eligibility and Guard Spec's first native residual decrement.
This is an item-effects-only partial import, not a fresh full-ROM import or
Emerald raw-byte gameplay validation. Neither the cartridge nor generated
cartridge data is part of the source change. The temporary consumer was removed
with file-inventory and SHA-256 guards after the native processes exited.

Evidence: `native-controller-status.json`, `native-old-cache-*-final.log`,
`native-firered-raw-import.log` and `native-install.json`. The recorded runtime
is `33c8588`; the status file also records the exact driver hash. Reproduce
with `POKEPORT_DRIVER=tests/drivers/enemy_decision.lua` in an isolated identity.
The optional `POKEPORT_ITEM_EFFECT_ROM` selects a local FireRed cartridge for
the in-memory item-effects stage; it is never needed for the old-cache cases.

## Mod-defined GBA class milestone

Explicit `ai_classes` class records now run before the public native switch/item
hook. Their allowance follows the party Pokemon across switches, while their
item actions reserve the same native stock as automatic decisions. Tested
branches include chance/status/HP gates, class switches, empty stock, class/layer
selection, the right double slot and returning Pokemon with exhausted uses.
The previous engine produces sixteen concrete class-action/precedence failures
in `class-host-negative.log`; the native reference passes those cases.

An unchanged public entry also registers, reads, patches, overrides and iterates
an AI class with canonical `POTION` / `FULL_RESTORE` item IDs. This exposed a
real host reference-resolution gap: Gen-3 physical `ITEM_nnn` keys previously
made the same class fail to load. The unified-content boundary now resolves
only this item reference and returns detached canonical records, including
write results. Legacy/native format is unchanged. API-2 contract fixtures
explicitly opt into unified content as well as callbacks. Separate Gen-1–3
loader checks cover missing items without recorded operations, finite/cyclic
validation, optional deletion, frozen writes, owner rollback, dangling native
references and legacy keys; the full unified-content suite passes **442/442**.

The decision matrix passes **12 workers / 413 paired observations** in each
of API 3 and host API 2/unified. It includes real single/double controller turns
with class items executing before a suppressed public hook. Focused host checks
pass **1,144/1,144**. The complete feature run remains **139/149** engine suites,
**3/3** SDK suites and B30; its **26** failure lines exactly match the ten prior
baseline suites. Reports are `contracts-class.json`, `contracts-class-api2.json`,
`targeted-class.log`, `unified-class-content.log` and `full-class.log`.

Native LÖVE 11.5 runs pass on Gold/FireRed/Emerald existing caches and a separate
FireRed in-memory item-effects import. FireRed/Emerald drive actual FIGHT/move
inputs through a class item before the hook and a second turn after its use
is exhausted. These native sessions supply bounded in-memory class/party/stock
records; public class registration is covered by the separate shared SDK
contracts, not claimed as a new full-ROM class import. The source runtime is
`cfcf3c4` plus the recorded development changes. Evidence and driver hash are
in `native-class-status.json` and `native-class-*.log`. The owned consumer was
removed with hash guards after all four processes exited.

Required before publication:

- Exercise actual imported Gen-2 attributes and stock through ordinary turns.
  Constructor/rematch isolation is covered, as is an old cache without flags;
  native policy with freshly imported class attributes still needs gameplay proof.
- Extend the FireRed raw-effects smoke to Emerald, both native double slots,
  further trap/status construction and imported stock boundaries.
- Audit mutations of delegated native actions (kind, slot and battler as well
  as item/type/flags), and GBA brain callback/selection precedence. Class
  item/switch precedence is now covered.
- Review participants, Pursuit, hazards/abilities and stale queued actors after
  forced switches. Keep native battle-rule gaps explicit rather than counting
  them as equal contract observations.
- Run the complete feature/combined validation before publication. The combined
  testing branch does not yet contain this unfinished hook.

Commands (the reference must be clean at the pin):

```sh
LUA=/path/to/luajit bash scripts/test.sh --quick
python3 tools/enemy-decision-contract-check/check.py --gen1 /path/to/gen1 --lua /path/to/luajit
python3 tools/enemy-decision-contract-check/check.py --gen1 /path/to/gen1 --lua /path/to/luajit --host-api 2
```
