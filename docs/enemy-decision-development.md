# Enemy switch/item contract development

This branch is an in-progress implementation, not a published or fully validated
portability PR. It is based on published metadata prerequisite #173. The hook work itself
is not included in the combined testing branch until native decisions are ready.

The definition-record adapter originally developed on this branch is isolated
in [PR #174](https://github.com/UNDERdecoded/Gen2Recomped/pull/174): common
AI-class item names and detached API-3 content records, plus unchanged public
SDK consumers. It has independent metadata validation and does not publish
this branch's battle hook. Gen1 API-2 live-record aliasing is explicitly outside
that common API-3 contract.

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

## Delegated action mutation milestone

The GBA bridge now translates the final mutable native action returned by
`next`, including an item changed into a switch/move, a changed switch slot and
claiming that edited result with `true`. Original native item consumption and
switch reservations remain committed; converting an action does not reserve a
second item. Item target edits do not redirect trainer healing. Ordinary
single controllers normalize the actor ID, while doubles reject mismatched or
missing right-slot actor IDs and use the reference's first usable move fallback.
Unknown native action kinds retain the reference's distinct single/double paths.

A delegated move spends PP from its selected party slot without rewriting that
slot's move ID. The controller comparisons now retain full HP, stage, PP,
remaining trainer-stock and move/switch event observations. Eleven additional
ordinary-turn cases per FireRed/Emerald exercise these boundaries. The identical
current tests run against a clean `840e11d` checkout expose **eight differing
observations per GBA version**, including the concrete switch-slot assertion
failure. Reports are `mutations-parent-firered.log`,
`mutations-parent-emerald.log` and `mutations-parent-differences.json`.
The temporary parent checkout was clean and removed after the negative controls.

Both API 3 and host API 2/unified pass **12 workers / 435 paired observations**
with zero differences. Focused host checks pass **1,192/1,192**. The complete
feature run remains **139/149** engine suites, **3/3** SDK suites and B30, with
exactly the same **26** failure lines across ten baseline suites.
Evidence: `contracts-mutations.json`, `contracts-mutations-api2.json`,
`targeted-mutations.log` and `full-mutations.log`.

Native imported-data runs pass on Gold, FireRed and Emerald, plus the separate
FireRed in-memory item-effects import. The GBA runs use actual FIGHT/move input
and presentation queues to verify item-to-switch, item-to-move and unknown-kind
fallbacks, their original stock reservation and selected-slot PP consumption.
The normal party move ID is preserved. Runtime is `840e11d` plus the recorded
changes; exact driver hash and four process results are retained in
`native-mutations-status.json` and `native-mutations-*.log`. These are bounded
sessions rather than complete playthroughs; the owned consumer was removed
with hash guards after all four processes exited.

## GBA mod-brain milestone

Mod-defined GBA brains now receive the reference's move-selector view after
class/item/switch decisions: the exact native battle, user, opposite target,
current data and RNG function, plus detached `{slot, move, usable}` candidates.
Move definitions preserve canonical names and numeric GBA effect/type metadata.
Numeric, string and `{slot=...}` choices are validated; invalid choices retain
the native fallback and a callback failure falls back through the opponent
controller. With no usable move, the brain is not invoked. GB class brains and
legacy direct trainer brains retain their existing action contracts.

Twenty-five shared query cases compare complete candidate definitions, native
handle identity, invocation order, choices and all RNG call ranges/order.
They cover PP, Disable, Taunt, Torment, Encore, Imprison and an existing Choice
lock, errors, unavailable slots, right-hand opponents and class/layer selection.
The FireRed versus Emerald tie-list difference is retained. Native bytecode
and scored-layer fallbacks still use the existing host AI; full program parity
is not established here. Synthetic Imprison/Choice-lock inputs prove the read
boundary, not missing native producers or complete Choice Band locking.

Five additional ordinary brain turns compare single/double second-slot choices,
item precedence, zero PP and error fallback. Full party PP arrays, HP, stock,
move/switch events and brain views remain in the observations. A native Encore
controller case proves that trainer items execute before its forced move;
Encore no longer bypasses the native item/switch decision on GBA. A further
mutated double-move case verifies the chosen opposite slot. Native slot IDs
are converted to host target objects before target resolution.

Both API 3 and host API 2/unified pass **12 workers / 499 paired observations**
with zero differences. Focused host checks pass **1,530/1,530**. The complete
feature run remains **139/149** engine suites, **3/3** SDK suites and B30;
all **26** failure lines exactly match the ten baseline suites.
Reports: `contracts-brain.json`, `contracts-brain-api2.json`,
`targeted-brain.log` and `full-brain.log`.

The same current query tests run on clean parent `b7fb4c1` produce **51 actual
assertion failures and 24 differing cases per GBA version**, rather than a
missing-module failure. Reports are `brain-parent-firered.log`,
`brain-parent-emerald.log` and `brain-parent-differences.json`. The temporary
parent checkout was verified clean and removed after the negative controls.

Four native LÖVE 11.5 runs pass: Gold/FireRed/Emerald old-cache regression and
FireRed's in-memory item-effects import. GBA tests use actual FIGHT/move input
and result queues to select the second slot, preserve the other slot's PP,
inspect imported candidate metadata, contain an intentional brain error and
execute a trainer item before Encore/brain. These bounded sessions supply
in-memory class functions; shared SDK tests separately prove unchanged public
class registration. Runtime is `b7fb4c1` plus the recorded changes. Exact
engine/fixture/driver hashes and process results are in
`native-brain-status.json` and `native-brain-*.log`. No normal SAVE or full
playthrough is claimed. The owned consumer was removed with hash guards.

## Delegated native controller fields

Thirty-nine additional controller cases per GBA version now cover `meta`,
`done`, `finished`, watch rows carrying moves, run/forfeit, claim-after-next,
SLP/FRZ, explicit escape prevention and Shadow Tag/Arena Trap/Magnet Pull.
They retain native single/double differences: single move rows lose `meta`,
single non-move rows retain it; doubles ignore `meta` and skip done/finished
rows. Single watch rows can execute their retained move and target, while
double watch rows spend the action. Single enemy run uses the sleep/freeze,
trap and native ability gates; double trainer run fails unless forfeiting.

The matrix exposed critical/type rounding independently of the decision hook:
base damage 11, critical x2, Steel resistance and random 85 must deal 9 HP,
not 8. The Gen-3 ruleset now puts its critical multiplier before STAB/type
rounding, with an explicit profile flag. Other profiles retain their ordering.
Fifteen focused arithmetic checks cover this and surrounding boundaries. The
escape fixtures also mount the same Normal/Ghost/Steel type rows as the
native reference; their original neutral-only host chart was not equivalent.
The rounding fix is isolated and published in
[PR #175](https://github.com/UNDERdecoded/Gen2Recomped/pull/175), with its own
unchanged critical-hit consumer and imported-data driver. It does not publish
this branch's enemy hook or require the unfinished controller implementation.

Both host API modes pass **12 workers / 577 paired observations**, with no
differences, and host hook checks pass **1,812/1,812**. The complete development
run passes **140/150** engine suites, **3/3** SDK suites and B30. All **26** FAIL
lines exactly match the earlier ten baseline suites. A first run caught an
inline Strings import the coverage gate could not recognize; it is now a
normal local import and the failed log remains separately recorded.

The same current cases on clean `f805ee6` produce **15 differing observations
and 8 assertion failures per GBA version**. The temporary parent worktree was
verified clean and removed. Reports: `contracts-controls.json`,
`contracts-controls-api2.json`, `targeted-controls.log`, `full-controls.log`,
`controls-parent-differences.json` and the two parent logs.

Four native LÖVE runs pass: Gold, FireRed and Emerald old-cache regression,
plus FireRed's in-memory item-effects import. New GBA cases use actual FIGHT,
move/target input and single/double queues; they check watch damage, meta/done
fields, blocked run, fled/forfeited finish, original stock reservations and
party PP. Actual imported Steel damage is 9 in both GBA games. These are
constructed in-memory battles with the same public consumer, not a complete
playthrough or normal SAVE test. Runtime is `f805ee6` plus the recorded changes;
exact hashes/results are in `native-controls-status.json` and associated logs.
The owned example was removed after hash verification.

## Gen-2 ordinary turns and real cartridge inputs

Twelve additional ordinary turns per Gen-2 version compare native healing,
stock exhaustion, duplicate Full Restores, suppression, repeat/failure after
delegation, highest-level and half-HP gates, and missing attributes. They run
the native turn controller and presentation queues, not just the item query.
Fixtures now mount actual Gen-2 physical item indices, generation metadata
and equal session stats/nicknames. The complete matrix passes **12 workers /
613 paired observations** in each host API mode. Host hook checks pass
**1,884/1,884**, and seven separate Gen-2 critical-base regressions pass.

These cases exposed two product defects. Gen-2 stock consumption compared a
resolved physical key against an unnormalized alias and could leave a Potion
in stock. It now compares resolved keys while removing exactly one slot.
Gen-2 critical damage doubles the truncated base before the cap and +2;
doubling the level instead used the wrong floor at levels such as 29. Native
generation metadata now selects that base step; Gen-1's existing level rule
and the Gen-3 profile remain separate. Other Gen-2 modifiers/rules are not
claimed universally equivalent by these regressions.

The critical-base correction is isolated and published in
[PR #176](https://github.com/UNDERdecoded/Gen2Recomped/pull/176), with the same
public critical-hit consumer on five Gen-2/GBA profiles and a separate native
Gold driver. It does not publish the unfinished enemy switch/item hook.

The unchanged `784c8ec` parent fails **4 critical-base assertions** and the
alias-stock constructor assertion, with **one differing ordinary-turn HP
observation** on Gold. The temporary checkout was verified clean and removed.
Reports: `contracts-gen2-turns.json`, `contracts-gen2-turns-api2.json`,
`targeted-gen2-turns.log`, `gen2-critical-base.log`, `gen2-parent-*.log` and
`gen2-parent-differences.json`.

The actual English Gold ROM, SHA-1
`d8b8a3600a465308c9953dfa04f0081c05bdcb94`, is read through each native trainer
importer and its own manifest: **all 66** seven-byte attribute rows and ordered
item stocks agree. The host uses setup constants from an existing cache of
that same ROM. Feeding the freshly read Red attributes/stock into the native
turn fixtures produces **13 equal metadata/turn observations** through both
SDKs. Private cartridge-derived reports remain in the ignored QA directory;
no ROM/cache assets are committed. See `fresh-gold-comparison.json` and the
two `fresh-gold-*-turns.log` files.

The new native `tests/drivers/enemy_decision_gen2_import.lua` also passes on
LÖVE 11.5. It imports the Gold trainer stage into memory, constructs Red's
actual six-Pokemon roster (level-81 lead), and runs four real FIGHT/move turns
across two encounters. Both Full Restores are consumed once, the third turn
has no stock, the shared imported class remains unchanged, and a new encounter
gets both slots back. Each ordinary turn reaches the public hook once with
the exact battle handle. The ROM must match the isolated cache; no complete
fresh-ROM import, battle finish or normal SAVE is claimed.

The GBA driver now accepts the Emerald item-effect ROM stage too. The actual
Emerald raw-effects run passes its single/double controllers, including both
item recipients, run/forfeit/flag checks, X Attack, Guard Spec/Mist and the
Steel critical regression. This extends the earlier FireRed raw-effects
evidence; it does not establish every imported trainer-stock/status boundary.
Native hashes and results are in `native-gen2-import-status.json`,
`native-emerald-raw-status.json` and their logs. The owned example was removed
with hash guards after both processes exited.

The complete development run passes **141/151** engine suites, **3/3** SDK
suites and B30. All **26 FAIL lines** exactly match the prior ten baseline
suites. Runtime is `784c8ec` plus the recorded changes. The unfinished hook
remains outside the combined testing branch.

Required before publication:

- Extend real imported Gen-2 coverage beyond Gold's actual attributes, stock
  and ordinary/rematch turns. Silver/Crystal synthetic controller contracts
  pass; their own native ROM/controller paths and more switch policies remain.
- Extend raw GBA controller coverage to further trap/status construction and
  actual imported trainer-stock boundaries. Both GBA item-effect stages and
  both native double recipients are now covered above.
- Extend delegated-action coverage to malformed slot/move payloads and unsafe
  watch targets. Keeping the original numeric item target on a single watch
  action crashes the current reference controller; the valid-target cases
  above do not establish a portable malformed-action contract. Ordinary item,
  switch, move, actor-ID and controller-flag paths above are covered.
- Extend native bytecode/scored-layer fallback coverage beyond the tested
  brain choice and unscored-class paths. Existing Imprison/Choice-lock flags
  have validated read semantics; their complete native producers/rules remain
  separate battle work.
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
