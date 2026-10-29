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

Qualification is pending. The new pure-data test covers all65536legal gene
vectors and all256gender ratios against all256Attack/Speed pairs, without
LOVE or presentation imports. The SDK test uses actual callbacks, live native
Pokemon/definitions, retirement and RNG ownership. These fixtures do not
establish the remaining constructor/experience/caught-data/battle APIs or
complete visual/release acceptance. No mod or protected/player copy changes.

Integration/tests by Roxas2712; applicable project rights and prior grants
remain effective. See NOTICE.md and LICENSE-ROXAS2712.md.
