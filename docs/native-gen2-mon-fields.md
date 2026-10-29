# Live native GSC Pokemon fields

Source GSC consumers read `mon.maxHp`, `mon.name`, `mon.types`, and
`stats.specialAttack`/`stats.specialDefense`. Native Pokemon store their
maximum in `stats.hp`, look up species display/types from the data registry,
and use `spatk`/`spdef`. A real native birth on preceding source `a6eb0c05`
fails all five source-field checks; the implementation module is absent too.
Unchanged menu, healing and capture consumers can consequently read missing
maximums or special statistics despite the native combat values existing.

`Gen2MonFields` supplies those spellings on the actual native tables.
Reads follow native stat-block replacement and live registry changes;
source stat/maximum writes reach their native canonical fields. Construction,
save validation, the native battler data factory and identity refresh bind
the original Pokemon. Native GSC stat calculation/rehydration and the
species registry writer publish split-stat aliases. Data seeding and actual
mod loading also expose the base-stat spellings used by source consumers.
There is no parallel Pokemon, duplicated HP counter or per-frame polling.

Aliases live on metatables, without adding helper keys to serialized records.
Explicit authored stored fields retain their existing precedence. Existing
custom metamethods are preserved; protected custom metatables are not
replaced and may therefore decline the additional fields. Live Pokemon retain
their data owner; abandoned Pokemon/data cycles remain collectible on LuaJIT.
The helper does not allocate graphics or install a fake LÖVE runtime.

Selected qualification on corrected source `2a000267`:

- 156 pure-data checks with no LÖVE, including live owners, canonical writes,
  replaced registries/stat blocks, custom/protected tables and cycle collection.
- 162 actual native checks across the registered editions: birth, real save
  encoding/decoding/validation, native battlers and source model, box stats,
  actual SDK loading and native registry writes. Non-GSC Pokemon are excluded.
- Existing data construction 691, native construction/art hydration 972,
  identity ownership 142, species identity 145 and save-summary 50 checks pass.

Native mod loading also accepts bounded canonical `spatk`/`spdef` patches
through its strict nested Pokemon schema. The real SDK probe patches both
columns, rather than bypassing validation with direct registry calls.

The first full run on `4590148b` passed933/946 engine suites;13 checkpoint
groups rejected the new native metatables as opaque. Semantic codecs now
authenticate only the helper's unchanged plain native wrappers, serialize
only raw record entries and restore native field views on reconstructed
saved Pokemon and current combat stats. Custom/protected/copied/edited
metatables remain opaque. World reconstruction binds actual party, sparse
boxes and native daycare slots without inspecting mod storage, rolling
identity, recalculating stats or changing serialized progress. A dedicated
real world/battle checkpoint probe checks raw snapshots, restored live
aliases, separate transformed current stats and byte-identical recapture.
Corrected source `23d4aaa5` passes184 pure-data,177 actual native and100
semantic-codec checks, plus all13 previously failing checkpoint suites.
Complete current-tree qualification is pending; the first failed full
receipt must not be treated as a passing current-tree result.

The first implementation lost custom metamethods on a cache miss; four pure
checks caught it. The corrected cache selection passes all checks. The same
native probe on the preceding committed engine fails six checks, including
the five observed field gaps. Complete current-tree, unchanged-mod GPU/menu
and final release qualification remain open. This does not implement the
still-missing standalone source battle constructor or turn/event executor.

No mod, protected Gen1 installation, ROM original or player profile is edited.
Existing engine authors' rights remain effective; native field integration
and tests by Roxas2712 are subject to `LICENSE-ROXAS2712.md`.
