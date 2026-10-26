# Fixture link fingerprint audit

The previous `7de3051a7b3c108e` pin was already stale at Gen2Recomped's
`0b8c9c4` import: that checkout computes `8c94d595cd60ca69` against its own
ROM-free fixtures. It is not a baseline that current Gen2 data can satisfy.

At upstream `13af468b97dc37015d14ad5c71d7f067c3ee810d`, the same production
serializer and digest compute `41e69caf4afa35ab`. Comparing the canonical
`Fingerprint.surface(data, {})` strings against `0b8c9c4` changes **only**
`move_effects`: commit `3252aec` adds these four full-handler registry records:

- `POWER_BASED_ON_LOW_SPEED` (Gyro Ball)
- `INCREASE_POWER_WITH_MORE_HP` (Wring Out / Crush Grip)
- `DOUBLE_POWER_WHEN_BELOW_HALF` (Brine)
- `DOUBLE_POWER_HEAL_SLEEP` (Wake-Up Slap)

No records were removed or altered in the serialized surface comparison.
The current surface has 198 effect records. Species, moves, type chart,
statuses, constants and mod list are byte-identical to the imported checkout.
An independent Python implementation using integer XOR, multiplication by
16777619 and modulo 2**32 in both lanes also produces the current digest.
No fingerprint algorithm, allowlist, cache or production registry is changed
by this test repair.

`fixture_fingerprint_sections.txt` pins each populated section separately so
future intentional registry additions cannot hide changes in another section.
`gate_fingerprint.lua` retains all prior mutation and determinism assertions,
and additionally proves that removing any of the four Sinnoh registrations
changes compatibility. An empty `link_fields` registry has no serialized
section; a future nonempty one requires a deliberate new section pin.

To audit a future change, load a fresh `tests.modkit` fixture with
`T.sdk.loadNone({data=data})`, compare `Fingerprint.surface(data,{})` section
by section, and then update only reviewed pins. Run the gate again and keep
the mutation assertions enabled. The ROM-dependent vanilla golden is separate
and was not re-blessed by this update.

## Native GBA Follow Me (#196)

The intentional `FOLLOW_ME_EFFECT` primary record adds one native registry
entry. With it the full fixture digest is `128fc071ae7249cd` and the
`move_effects` section is `7cd0ac0f527968fb`. Removing only that entry
restores full digest `41e69caf4afa35ab` and section `3bef37494ca4a845`.
All six other populated section digests stay identical. Only these two pins
change for this integration; mutation/determinism checks remain enabled.

## Native GBA Helping Hand

The intentional `HELPING_HAND_EFFECT` primary record adds one native registry
entry. The full digest becomes `032184f68094e9ca`; the `move_effects` section
changes from `7cd0ac0f527968fb` to `52cc8398513ed12c`. Removing only that entry restores
the former full digest `128fc071ae7249cd` and effect section. All six other
populated sections stay identical. Mutation and determinism checks remain enabled.

## Native GBA Spit Up revision

`SPIT_UP_EFFECT.rev = 1` marks its corrected set-damage behavior. The full
digest becomes `397df21576af62f1`; `move_effects` changes from
`52cc8398513ed12c` to `c62807cde682a669`. Removing only that record revision
restores full digest `032184f68094e9ca` and the former effect section. All six
other populated sections stay identical; no other golden or algorithm changes.

Beat Up party execution increments `BEAT_UP_EFFECT.rev` to 1. Audited fixture
digest `397df21576af62f1` becomes `d518411055f17444`; only `move_effects`
changes (`c62807cde682a669` to `f45a80ce5e45ef42`). Removing the revision
restores the former full digest. Other sections and mutation checks remain
unchanged. See `docs/native-gba-beat-up.md`.

Beat Up's native joined side-party execution increments `BEAT_UP_EFFECT.rev`
from 1 to 2. Audited fixture digest `d518411055f17444` becomes
`fdbfa30b20cbbaef`; only `move_effects` changes (`f45a80ce5e45ef42` to
`e4d28f474c15cd8b`). Restoring revision 1 restores the prior full digest;
all six other populated sections remain unchanged. See
`docs/native-gba-beat-up-side-parties.md`.

Native critical guards change scripted Beat Up's policy and increment
`BEAT_UP_EFFECT.rev` from 2 to 3. Audited fixture digest
`fdbfa30b20cbbaef` becomes `a000e3862d11a73a`; only `move_effects` changes
(`e4d28f474c15cd8b` to `cca86e08b893522c`). Restoring revision 2 restores
the former digest. The other six populated sections remain unchanged. See
`docs/native-gba-critical-context.md`.
