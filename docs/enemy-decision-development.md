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

Current source: clean `Roxas2712/gen1recomp-Mac-fix` at
`10613015fc68d924915570bd1abee34b70d5bd01`, the paired Taunt predicate fix in
[Gen1 PR #3052](https://github.com/bryanthaboi/gen1recomp/pull/3052).
Earlier milestones retain their recorded upstream `535a5ec` source evidence.
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

## Mod-defined GBA scoring milestone

The public `ai_classes` scorers now use the GBA move-selection path rather
than the legacy Gen-1 minimum-score fallback. Literal `aiMods` IDs run in
order, preserving duplicates, followed by an explicit layer class. Only a
function-valued score on a `layer` or an unspecified kind is eligible; brain
and action-class scores cannot accidentally become layers. Base scores are
100 for usable slots and zero for limited slots, and native maximum/tie
selection preserves the FireRed/Emerald RNG bounds.

An unchanged public scorer entry runs through both real SDKs. Thirty-eight
new cases per GBA version compare callback order, incoming scores, selected
physical slots, exact native battle/user/target/data/RNG identities, and RNG
ranges/order. They include class-only and mods-only records, a class appended
last, duplicates, numeric/unknown IDs, nil/false/zero/negative/infinite/NaN
returns, callback/type failures, callback RNG, empty/duplicate move slots,
PP/Disable limits and valid/invalid/error brains. One view persists across
slots; each slot gets its own detached move view shared by its successive
layers. A scorer cannot mutate the underlying move definition through that
view.

Supported native program scores feed the layers before selection, including
multiple flag bits, disabled and zero-PP moves, and sparse physical slots.
Emerald's loaded per-target double branch preserves the reference's bypass
of mod layers, considers the partner, and retains its setup/target/tie draws.
Missing packs still permit the normal mod layers. The program fixtures use
actual native VMs with equal conditional/score/end instructions in their own
importer formats. These bounded programs do **not** establish full VM opcode,
simulated damage RNG, action-control or imported trainer-program parity.
Unsupported programs retain the host VM's existing coverage limitations.

The matrix passes **12 workers / 689 paired observations** in each of API 3
and host API 2/unified, with zero differences. Host checks pass
**2,518/2,518**. Running the same new consumer and cases on clean `0812422`
produces **35 differing observations per GBA version**; its failed assertions
are recorded without treating them as current failures. The temporary parent
checkout was clean before and after and has been removed.

The complete development run remains **141/151** engine suites, **3/3** SDK
suites and B30. Its **26 FAIL lines** exactly match the prior ten baseline
suites. Runtime is `0812422` plus the recorded scoring changes. Reports are
`contracts-scoring.json`, `contracts-scoring-api2.json`, `targeted-scoring.log`,
`full-scoring.log`, `scoring-parent-differences.json` and
`scoring-parent-{firered,emerald}.log` in the ignored QA directory.
This milestone is CPU/native-controller selection evidence, not a new LÖVE
smoke or full playthrough. The unfinished hook remains outside the combined
testing branch and is not yet published as a PR.

## Native GBA random-branch milestone

All four bytecode random comparisons now consume a native u16 draw and
compare its low byte. Previously the host drew only 0–255 for less/greater
and refused entire reachable scripts containing equal/not-equal. This
independent correction is published in
[PR #177](https://github.com/UNDERdecoded/Gen2Recomped/pull/177), based directly
on upstream `main`; it does not publish this development hook.

The unchanged public scorer now includes 32 additional native random-program
cases per GBA version. Both API modes pass **12 workers / 753 paired
observations**, with zero differences. Focused host checks pass
**3,094/3,094**, and the separate native-VM suite passes **1,920/1,920**.
The complete development run passes **142/152** engine suites, **3/3** SDK
suites and B30; all **26 FAIL lines** exactly match its preceding ten-suite
baseline. Runtime is `3280941` plus the recorded random-branch changes.
Reports: `contracts-ai-random.json`, `contracts-ai-random-api2.json`,
`targeted-ai-random.log`, `ai-random-contracts.json` and `full-ai-random.log`.

The PR adds a reproducible optional read-only Emerald ROM check alongside
its ROM-free 240-pair matrix. Each native importer independently decodes the
same actual cartridge into memory. The actual interpreters match on **39
common RNG-only subroutines / 390 observations**. The report exposes 42
additional host entry boundaries as unpaired, and fails if any eligible
reference entry is missing. Clean upstream differs in all 390 traces and
41 resulting scores; it fails 631 synthetic assertions per GBA version.
These are bounded real-import/VM checks, not complete trainer decisions or
new LÖVE gameplay runs. The isolated feature's own complete run matches all
27 upstream baseline failure lines exactly (65/75 versus upstream 64/74).

The fresh Emerald AI stage contains 1,745 instructions and 142 less-than
random comparisons. The new equality operators are not present in that
cartridge's imported instruction set; the broader operator checks are
synthetic native programs, not a claim to unlock more of Emerald's stock
scripts. Whole-script support still lacks native query opcodes, and existing
damage-estimation simulation/rules require further parity work.

## Native damage-query and simulation milestone

GBA trainer move selection now captures the four native setup rolls once,
keeps them tied to physical slots (including holes/zero PP), and supplies the
same values to every native program pass. Emerald's per-target path gets its
own four values for each considered target. `Gen3AI.estimate` no longer
spends a separate lazy 0–9 roll. The VM's missing setup input defaults to 100,
as in the reference VM; ordinary trainer controllers provide the setup table.
The GBA bridge also handles trainers without a custom class or mod layers,
including zero native flags, using the reference's base/tie selection.

The unchanged public scorer is composed with actual native KO and power
query programs. Ninety-nine cases per GBA version cover HP boundaries,
flipped/equal rolls, fourth-slot holes, PP/Disable, multiple scripts,
power-0/1 guards, default trainers, STAB, immunity/resistance, burn/stages,
weather, wide stats and doubles. Each case compares actual selected slots,
callback input scores, complete controller RNG order and numerical estimates
from the real calculator seams. Explicit assertions verify equal session
Attack/Defense inputs. No copied AI or damage formula supplies the result.

These checks also exposed the VM's unbounded bytecode score addition and
inverted status-move `if_cant_faint` behavior. Bytecode scores now match the
reference's 0–127 clamp, while mod-defined layer returns retain their existing
semantics. Both KO operators ignore power below two. Estimation carries the
native weather input and suppresses defender-screen inference, matching the
reference AI damage query's options rather than adding a different model.

The numeric comparisons exposed older-generation base steps in shared GBA
damage. Their independent correction is published in
[PR #178](https://github.com/UNDERdecoded/Gen2Recomped/pull/178): wide stats,
base limits/minimum, burn/screens/spread/weather before +2, and Solar Beam's
bad-weather step. Both actual ordinary calculators match in **4 workers /
6,912 paired observations**, with **20,742** host/older-profile checks.
That PR does not publish this hook or its AI wiring.

The development decision matrix passes **12 workers / 951 paired
observations** in each of host API 3 and API 2/unified, with zero differences.
Host hook checks pass **4,084/4,084**. The complete development run passes
**143/153** engine suites, **3/3** SDK suites and B30; all **26 FAIL lines**
exactly match the preceding ten-suite baseline. Runtime is `0e3baf8` plus the
recorded changes. Reports are `contracts-damage-ai-final.json`,
`contracts-damage-ai-final-api2.json`, `full-damage-ai-final.log` and
`gba-base-contracts.json` in the ignored QA directory. These remain bounded
native-controller selection/calculator checks with explicit synthetic session
inputs, not actual imported trainer-program coverage, a new LÖVE run or
complete native battle parity. The unfinished hook remains outside the
combined testing branch.

## Native move/battler query milestone

`Gen3AIQueries` supplies seven functional native query families: last-used
move (both command names), move type/power/effect from the result register,
protection count, active types and Flash Fire. It reads current typed records,
preserves native type numbers across aliases and declared custom indices,
handles absent partners, and rejects unknown move definitions without
inventing a zero result. MOVE_NONE retains the native zero row. These queries
do not consume RNG. This independent prerequisite is published in
[PR #179](https://github.com/UNDERdecoded/Gen2Recomped/pull/179).

The direct interpreter matrix passes **4 workers / 472 paired observations**
and **2,339** host checks. It includes all native type numbers, both importer
names, declared custom type indices, metadata/error boundaries and the
reference's distinct legacy versus partner-aware selectors. Clean upstream
fails 702 assertions and differs in 236 observations per GBA profile. Its
complete run matches all 27 existing upstream failure lines exactly.

The unchanged public scorer also passes through the real trainer constructors
and opponent query producers, including singles/doubles, normal and invalid
metadata, missing history, counters and partner state. Actual native attacks
populate the last move; a Fire hit triggers Flash Fire; an actual Protect
produces its counter before the AI reads it. Those checks use the real move
pipelines and equal explicit session/ability inputs, not hand-set producer
results. They are CPU selection/move-query checks, not a new graphical turn
or complete ordinary presentation/controller run.

Both host API 3 and API 2/unified pass **12 workers / 995 paired observations**,
with zero differences. Hook checks pass **4,178/4,178**. The complete development
run passes **144/154** engine suites, SDK **3/3** and B30; its **26 FAIL lines**
exactly match the preceding ten-suite baseline. Runtime is `9e8983a5` plus the
recorded query changes. Reports: `query-contracts-expanded.json`,
`contracts-queries.json`, `contracts-queries-api2.json` and `full-queries.log`.

A fresh actual Emerald AI-stage audit still reports runnable flag programs
0, 1, 3, 4 and 5; the new queries alone do not prove more complete stock
programs. Flag 2 still needs held effects, move/effect membership, party
status, taunt and speed/attacking-move predicates. Flag 6 needs effect
membership; flags 7–9 still need move/held-item knowledge. Source-side held
effect, gender, used-item and taunt handlers include placeholders, and
existing weather ordinals/aliases also need a semantic audit. Do not port
placeholders or count opcode names as full parity. Actual program audit:
`audit-emerald-ai-queries.log`. The unfinished hook stays outside the
combined testing branch, whose independently validated PR-179 snapshot
passes 200/200 engine suites.

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
- Extend native bytecode coverage beyond the tested random/score/KO/power
  programs, including remaining query opcodes and existing handler semantics,
  reference-side placeholder providers, variable-power move effects,
  ability/held-item contexts, action controls and actual imported trainer
  programs. Setup RNG and ordinary numeric damage queries now have shared
  contracts; that does not prove all native damage/AI rules. The public
  brain/scored-layer paths and Emerald loaded-program bypass are covered.
  Existing Imprison/Choice-lock flags
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

## Native GBA move-knowledge milestone

[PR #180](https://github.com/UNDERdecoded/Gen2Recomped/pull/180) independently
publishes the four native move/effect membership commands and Emerald's
per-battler observed-move history. The independent feature passes 19,116 checks
and 4 workers / 3,072 paired actual-interpreter observations. FireRed retains
actual-move reads, including empty/unknown-name boundaries. Unsupported
commands still reject complete scripts.

Development runtime `cf21d7ce5982e861557e5d056bd9c1449d5402a4` additionally
wires learning into the ordinary public scorer/controller path: once after
single-target setup, including a valid mod brain, or per opposing target in
the loaded Emerald double-program path. Learning preserves unrelated history,
order, duplicate suppression and the four-move cap. Switching party identity
invalidates the previous occupant's knowledge. It does not reveal unobserved
moves or consume RNG.

Sixteen additional cases per GBA profile pass through the unchanged public
scoring consumer and actual native opponent entry points. They cover positive
and negative membership, unseen effects, zero PP, live/absent/fainted partners,
Emerald's asymmetric partner selectors and actual move-produced history.
Focused checks pass **4,246/4,246**. Both host API 3 and API 2/unified match
the pinned source in **12 workers / 1,027 paired observations** each.

The complete development run passes **145/155** engine suites, SDK **3/3**
and B30. All **26 FAIL lines across ten inherited suites** match the previous
query milestone exactly. Reports are `contracts-knowledge-final-clean.json`,
`contracts-knowledge-final-clean-api2.json`, `targeted-knowledge.log` and
`full-knowledge-final.log` under ignored `tmp/enemy-switch-item-qa/`.

A read-only fresh English Emerald AI-stage import now reports flag 6 as
runnable. Flags 7–9 still require `if_holds_item`; flag 2 still requires held
effects, party status, taunt, move-order and attacking-move queries. This is
reachability evidence, not proof of full stock-program/controller parity.
No graphical run is added. The unfinished enemy switch/item hook and its
extended controller wiring remain outside the combined testing branch.

## Live Taunt predicates and public scorer milestone

[Gen2 PR #181](https://github.com/UNDERdecoded/Gen2Recomped/pull/181) publishes
both native AI Taunt predicates, the two-tick GBA owned effect and cleared-zero
application behavior. The source counterpart replaces unconditional false/true
placeholders; other source production code is unchanged. The independent
interpreter/effect/residual matrix passes 567 host / 372 source checks and
4 workers / 96 paired observations. Both PRs are regular, published and
unmerged. Their hosted workflows await maintainer approval.

Development runtime `6e8e3ea7bfa0dc6bf8db6d8532b90bb7c21ab2b1` runs ten
additional cases per GBA profile through the unchanged public scoring consumer:
zero/live timers, both predicate directions, double targeting and actual
native `Engine.resolveMove` / host `performMove` Taunt production. The move
fixture uses equivalent declared records and controlled accuracy RNG, then
the real opponent query and public scorer read its produced timer. It does
not replace the timer or the predicate with an expected-result stub.

Focused checks pass **4,290/4,290**. Clean host API 3 and API 2/unified each
match the fixed source in **12 workers / 1,047 paired observations**, with zero
differences. Reports are `contracts-taunt-clean.json`,
`contracts-taunt-clean-api2.json`, `targeted-taunt.log` and `full-taunt.log`
in ignored `tmp/enemy-switch-item-qa/`. The full development run passes
**146/156** engine suites, SDK **3/3** and B30; its exact **26 FAIL lines**
remain unchanged across the ten inherited suites.

The paired source reference is explicit in the checker. Other historical
contract tools keep their own upstream pins. No graphical run or complete
stock-AI/controller parity is claimed. Held-item observations/effects, party
status and move-order predicates still require functional native contracts;
the unfinished enemy switch/item hook remains outside the combined branch.
