# Native GSC volatile state

Source consumers of the live Gen2 battle model use `volatile(mon)` to read and
write transient battle state. Previously, canonical names such as
`confuseCount`, `flinched`, `endure`, `recharge` and `protectCount` could become
unrelated extension metadata while the native controller read different fields.

These names now address the existing native battler's confusion counter,
flinch, Endure, recharge and consecutive-protection state. `focusEnergy` and
`xAccuracy` likewise address the native critical/hit-check flags. Existing
substitute, protect, mist and legacy aliases remain available. Unknown fields
remain consumer-owned metadata; they do not establish native mechanics for
other source fields.

Views belong to the transient live model, not a module-global weak-key cache:
LuaJIT can retain a weak key through closures in its associated value. Queries
retire withdrawn battler entries. The same active owner keeps a stable view;
new native wrappers get new views. Neither views nor extension metadata enter
party records, battler serialization or semantic checkpoints. Native counters
and flags continue through the existing checkpoint whitelist and receive fresh
views after reconstruction.

GSC protection-counter retention now follows the actual PROTECT/ENDURE effect,
including renamed moves. Reassigning an old PROTECT ID to another effect resets
the counter. This does not yet address all GSC protection mechanics: the shared
handler's RNG protocol, opponent-first and Substitute restrictions still need
their own reference comparison and correction.

Validation uses actual native battle owners and a loaded API2 source consumer:
423 state/mechanics/ownership/collection checks pass across Gold, Silver,
Crystal, Prism and Polished Crystal; 48 additional checks exercise real semantic
checkpoint reconstruction. The same corrected 423-check fixture produces 166
failures against the old implementation. Applying only the view correction
leaves 15 failures in actual protection-counter lifetime. Model (252) and native
checkpoint continuation (1387) regression checks also pass. These are ROM-free
CPU results, not unchanged-mod, GPU, complete model parity or release acceptance.

The source-field contract was inspected against the read-only Gen1Recomp Gen2
model at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. The native integration and
tests are contributions by Roxas2712 under `LICENSE-ROXAS2712.md`; existing
engine and third-party rights remain intact.
