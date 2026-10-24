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

The strict matrix passes **12 workers / 219 paired observations** in each of
API 3 and host API 2/unified. Each GBA version includes **39** named automatic
policy cases, a two-query double reservation and four actual native damaging
move/history cases. Real hits record landed move/attacker state; a Substitute
records the landed move without overwriting attacker state. Semi-invulnerability
and type immunity cannot invent hit history. A real Surf then drives the
ordinary resistance/counter decision, rather than supplying a fake hit record.
The host suite passes **317/317** focused checks. This remains bounded query,
effect and execution evidence, not complete native battle/controller parity.
The complete development run passes **139/149** engine suites, **3/3** SDK
suites and B30. Its **26** failure lines across ten baseline suites exactly
match the earlier development baseline; no new failure lines were introduced.
Logs/reports are retained under `tmp/enemy-switch-item-qa/` as
`full-switch-policy.log`, `targeted-switch-history.log`,
`contracts-switch-history.json` and `contracts-switch-history-api2.json`.

The implementation preserves Gen 2's imperative boolean query and GBA's
deferred action/stock-consumption contract. The public callback receives the
original battle handle, as in the reference. Native automatic selection and
presentation are still being audited; passing the current matrix is not a
claim of full AI or battle parity.

Required before publication:

- Wire and test #173's imported Gen-2 attributes/stock through the ordinary
  battle constructors, including old caches that lack these fields. The seven
  bytes are now imported; missing flags must not be fabricated.
- Use #173's raw GBA effect bytes for custom trainer items and battle-only
  effects, with explicit old-cache behavior. The parsed medicine view alone
  still omits individual X-item bits.
- Extend native trap/status construction, stock-boundary and imported-data
  cases beyond the bounded automatic-policy fixtures. Audit native action
  mutations and both GBA double slots beyond Potion.
- Exercise the ordinary turn/controller paths, forced/locked/tutorial/wild
  gates, native imported-data gameplay and the complete feature/combined suites.
- Review ordering, participants, hazards/abilities and stale queued actors.
  Keep further native battle-rule gaps explicit rather than counting them as
  equal contract observations.

Commands (the reference must be clean at the pin):

```sh
LUA=/path/to/luajit bash scripts/test.sh --quick
python3 tools/enemy-decision-contract-check/check.py --gen1 /path/to/gen1 --lua /path/to/luajit
python3 tools/enemy-decision-contract-check/check.py --gen1 /path/to/gen1 --lua /path/to/luajit --host-api 2
```
