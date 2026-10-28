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

Validation is pending execution of `gen2_model_rng.lua`,
`gen2_model_rng_link.lua`, `gen2_model_rng_checkpoint.lua`, the independent
frozen-reference stream comparison and native regressions. Static preparation
does not establish unchanged-mod, GPU, full model or release acceptance.
