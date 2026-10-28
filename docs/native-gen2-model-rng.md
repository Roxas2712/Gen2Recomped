# Native Gen2 model RNG

Expose `rng`, `random` and `roller()` on the live source model, backed by the
existing native controller's current function. LOVE-style ranges normalize
missing/small bounds and reversed ranges; the source random/roller domain is
zero-based for positive integer bounds. Queries consume no randomness and
retained adapters follow native function replacement, including link setup.

The source random field and decorated roller method stay distinct. The native
read-only reader policy remains in effect. Model-owned function caches do not
enter party mons or serialized battlers, and no second generator is created.
Standalone constructor/RNG-injection and complete source-model parity remain
separate work.

Reference: read-only Gen1Recomp Gen2 revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, `Battle.new`, its LOVE-style RNG
view and `Battle:roller`. This older host's native model, volatile-state and
protection prerequisites are offered separately. The fork-only semantic
checkpoint backend is absent here, so its checkpoint result is not inherited.

Native integration/tests by Roxas2712, offered to Cedric / UNDERdecoded under
the specific PR contribution permission, with existing rights intact.
Validation is pending independent execution on this offered host; no full
model/mod/GPU/release acceptance is claimed from static preparation.
