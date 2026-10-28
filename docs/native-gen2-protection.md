# Native GSC Protect and Endure

GSC previously inherited the shared Gen3 protection handler: first use consumed
no RNG, repeat uses drew from powers of two, Substitute did not prevent use,
and the second actor could protect after the opponent. When both actors chose
Protect, the generic incoming-status gate intercepted the self-targeted effect
before its own failure command could clear the counter.

`Gen2Protection` now runs these commands on the existing native battler and RNG.
The threshold is `255 >> prior_successes`; a native draw from 1 through 255,
minus one, must be below it. Threshold zero, Substitute and opponent-first
failures clear the counter before any draw. The actual action entry records
the round's first side, including switches and failed/recharge actions. Called
effects retain that side. The next round replaces it. GSC self-protection
reaches its own handler even when the opposing battler protects.

The native side/round markers survive semantic checkpoint reconstruction.
No second battle model, mod patch, or stored party field is introduced. Other
generations keep their previous protection handler and move-field fingerprint
allowlists.

Changed GSC command/RNG semantics advertise `gsc-1` in link hello and the
fingerprint's separate GSC domain. Old commands cannot enter a new lockstep
battle, in either direction. The fixture digest `40df18dc503213c8` was audited
with independent Python integer FNV over the legacy fixture surface and the
declared domain; the Gen1 legacy digest remains `e33d251961f2a41d`.

References: `pret/pokecrystal` revision
`5c877ef55197039c9676e8e3eec6d254b1c40fe8`,
`engine/battle/move_effects/protect.asm`; read-only Gen1Recomp Gen2 revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, `Battle.protectLike` and
`Effects.protectSucceeds`. The native nonzero-domain draw matches the reference
model's `random(255)` convention; this is not a claim of raw hardware PRNG or
zero-rejection trace emulation.

Focused results: 3796 native effect/queued-order/PP/switch checks, 66 actual
host/guest/spectator and admission checks, 30 semantic checkpoint checks,
394 shared protocol checks and the existing 37-check fingerprint gate pass.
An exhaustive independent frozen-reference run covers all 255 nonzero-byte
outcomes, counts zero through nine, both effects and actors across G/S/C:
30,624 actual effect cases and 165,336 comparisons pass. The initial native
negative control fails 1260 of its 3781 checks. These results cover the stated
protection behavior; they do not prove all called-move/turn mechanics, complete
Gen1 parity, unchanged-mod GPU behavior, Windows gameplay or release acceptance.

Original native integration and tests by Roxas2712, under
`LICENSE-ROXAS2712.md`. Existing engine and third-party rights remain intact.
