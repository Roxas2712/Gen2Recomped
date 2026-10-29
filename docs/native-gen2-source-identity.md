# Source GSC identity signatures

The source `Mon.isShiny(dvs, context)` signature was inherited from native
`Pokemon.isShiny(mon)`, which reads a different record shape. Source
`vanillaShiny`, `vanillaGender`, `gender` and `randomDVs` were also absent.
The adapter now sends original gene/definition/context arguments to shared
native GSC identity predicates and hook owners. Native births and live native
queries use the same owners; no replacement Pokemon or extra RNG stream is
created. Source `randomDVs` draws the native four genes in order and leaves
derived HP for the source birth boundary.

Vanilla predicates bypass hook dispatch. Hooked reads preserve source
truthiness, definition-first gender arguments, callback context identity and
fallback after permitted native-format edits. Existing GBA PID predicates,
native forced-shiny/cached identity owners and non-GSC behavior remain under
their existing native owners. Native legal GSC genes retain the same outcome;
the public GSC predicate also preserves the source's modulo handling.

Selected source `c38d06a6` independently passes262168pure-data checks and
450actual SDK/native checks. The new pure-data test covers all65536legal gene
vectors and all256gender ratios against all256Attack/Speed pairs, without
LOVE or presentation imports. The SDK test uses actual callbacks, live native
Pokemon/definitions, retirement and RNG ownership. Existing identity7232,
authority142, appearance5290, transaction63, stat-refresh238, PP6642 and
stat-data185360checks pass on the same candidate. Private receipt:
`native-selected-suites-1793248586646587000/receipt.json`.
The identical fixtures against predecessor main `4a28411d` fail25 real source
checks:5pure-data failures (including the incompatible inherited gene-input
signature) and20missing-method checks through the five actual GSC SDK hosts.
Failed receipt `native-selected-suites-1793248734445776000/receipt.json` is
retained as negative evidence, not a passing run.

Full composed-tree qualification is pending. These fixtures do not
establish the remaining constructor/experience/caught-data/battle APIs or
complete visual/release acceptance. No mod or protected/player copy changes.

Integration/tests by Roxas2712; applicable project rights and prior grants
remain effective. See NOTICE.md and LICENSE-ROXAS2712.md.
