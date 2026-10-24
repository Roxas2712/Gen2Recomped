# Enemy switch/item contract development

This branch is an in-progress implementation, not a published or fully validated
portability PR. It follows published #172 without changing the combined testing
branch until the native decision work is ready.

Current source: clean Gen1Recomp `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
`tools/enemy-decision-contract-check/check.py` runs the unchanged public consumer
through both real SDKs in separate workers. The current matrix covers Red's
unavailable producer and Gold/Silver/Crystal/FireRed/Emerald native query paths.
It exercises explicit real healing and switches, suppression/true/nil,
repeat/claim/failing `next`, stock reservation, modifying a delegated item,
native HP thresholds/status cures and right-hand GBA double slots. This is not
yet proof of complete native battle/controller behavior.

The implementation preserves Gen 2's imperative boolean query and GBA's
deferred action/stock-consumption contract. The public callback receives the
original battle handle, as in the reference. Native automatic selection and
presentation are still being audited; passing the current matrix is not a
claim of full AI or battle parity.

Required before publication:

- Add the missing Gen-2 imported trainer item/attribute metadata. The importer
  currently reads only the class reward byte. Native item/switch policy needs
  all seven bytes and the two stocked item references, not fabricated flags.
- Preserve GBA raw item-effect metadata needed by custom trainer items and
  battle-only effects. Existing parsed records omit individual X-item bits.
- Expand strict automatic-switch, trap/Perish/type/RNG and stock-boundary cases.
  Audit native action mutations and both GBA double slots beyond Potion.
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
