# Native Gen2 model RNG

The live Gen2 source model now exposes `rng`, `random` and `roller()` over the
existing native controller's stream. Before this change, an actual API2 source
consumer failed to find all three surfaces even though its native screen had a
working generator. The frozen-reference diagnostic recorded 18 failures across
Gold, Silver and Crystal.

`rng(n)` returns the positive 1..n domain. Its missing or smaller-than-one bound
normalizes to one, and a reversed two-bound range is normalized before calling
the native function, as in the source model's LOVE-style view. `random(n)` and
the function returned by `roller()` return 0..n-1 for positive integer n.

Adapters resolve the native function when invoked. Link constructors and scoped
native owners can replace `screen.rng` after model binding; an already retained
source adapter follows that current function. Queries and cache creation draw
no randomness. A source call consumes one native draw. Adapter identity stays
stable across queries and ordinary native switches.

The random field is independent of the class's decorated `roller` lookup, as
in the source model. A method decoration therefore does not implicitly replace
field reads. The existing native read-only reader policy applies to `rng` and
`random`. Standalone source constructors and independently injected constructor
RNG options remain separate full-model parity work.

Function caches belong to the transient model. No generator, closure, seed or
adapter cache is added to a party mon or serialized battler. Semantic checkpoint
reconstruction creates a fresh model and adapters over the restored native
random state. The model-owned caches can be collected with their owners.

The source contract is inspected against read-only Gen1Recomp Gen2 revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, `Battle.new`, `loveStyleRng` and
`Battle:roller`. Native integration and tests are original contributions by
Roxas2712 under `LICENSE-ROXAS2712.md`; existing rights remain intact.

Validation: 7951 native RNG/domain/replacement/switch/lifetime checks, 174 actual
host/guest/spectator callback checks and 45 semantic checkpoint checks pass.
Model (252), live-view (366), volatile-state (423) and protection-link (66)
regressions pass separately. An independent frozen Gen1 model comparison over
separately seeded actual native LinkBattle streams passes 9471 comparisons and
7020 draw cases, including every bound 1 through 256, normalized LOVE ranges,
current-function replacement and native switches in G/S/C. Reference source
hashes are unchanged. Whole-host/current-main, unchanged-mod GPU and release
qualification remain separate; these checks do not establish complete model
constructor/turn or injected-RNG parity.
