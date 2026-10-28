# Imported native fixed-damage moves

`RomExtractorGen3` publishes numeric IDs such as `MOVE_082` and the native
`gen3Effect` byte. The classic `SPECIAL_DAMAGE_EFFECT` looked up English
move IDs or an explicit authored `fixedDamage` field. As a result, imported
Dragon Rage, SonicBoom, Seismic Toss/Night Shade and Psywave failed before
dealing damage.

`Gen3FixedDamage` adapts that builtin before mods capture it. Native effect
bytes 41, 130, 87 and 88 select 40 HP, 20 HP, the user's level and Psywave's
native level-scaled amount respectively. Fixed damage does not roll critical
hits or ordinary damage variation, gain STAB, or scale with resistance.
Type immunity, Foresight, Levitate and Wonder Guard retain their native
recipient guards. Native fixed scripts report effectiveness on damage events
without printing the ordinary damage script's effectiveness message.

Direct damage calculations recognize the same native effect bytes without a
private script marker. Script calculations pass through `battle.damage`. The native `deferAdjustment`
and `psywaveRoll` option names are shared with Gen1. A hook returning an amount
without metadata retains its delegated calculation's immunity and type
metadata. FR/LG/E draw Psywave's 0..10 value inside that calculation; R/S run
the rejection command (0..15 until <=10) before the calculation hook.

Zero-power imported rows use the native status body, with no accuracy,
calculation, damage event or received-hit history. Complete authored
`chooseDamage` overrides remain authoritative for damaging rows. Explicit
`fixedDamage` fields and unrecognized native effect bytes retain the classic
handler. Both the registry and its vanilla fallback use the same adapter;
classic shared handlers and imported move rows are never rewritten.

The executable corpus uses the real move-byte importer over authored bytes,
then actual native commands, public calculation hooks, HP events and received
hit history. It covers singles, right-hand doubles and an absent left foe,
Substitute, Endure, Focus Band, resistance, Foresight and ability guards.
Amount-only hooks exercise the real metadata fallback. Separate suites run
complete menu rounds, cold checkpoint continuations and real linked peers. The corpus does not
require a game ROM or ordinary save profile.

```
python3 tools/gen3_fixed_damage_contract.py --reference-root /path/to/Gen1Recomp \
  --lua /path/to/luajit --qa-tools-root /path/to/current/tools --output /path/to/new/report
```

The contract compares fixed amounts, calculation/event boundaries and history;
it also retains and independently compares every raw RNG call. R/S post-hit
chance-opcode calls and Focus Band's pre-immunity command placement remain
open, so a passing fixed-damage contract does not qualify complete R/S RNG
parity. General R/S damage variation, Super Fang/Endeavor/Counter policies,
per-hit held items and complete original-mod gameplay remain separate work.
The global GBA readiness flag remains disabled.

GBA command revision **23** prevents older fixed-damage semantics from entering
lockstep. The historical revision-22 fixture digest is `0532b5c0de70029c`;
revision 23 is `44c5b775413306c1`. Earlier-generation fingerprints and the
native party codec are unchanged.

Qualification of this slice: **6,600 paired cases** across 60 isolated engine
workers agree on amounts, public calculation options/boundaries, HP events
and received-hit history. **14 focused suites / 61,447 checks** pass, including
complete rounds, cold reconstruction and linked peers. Inputs and logs were
independently rehashed. FR/LG/E also agree on the entire raw RNG stream in
this corpus. R/S retain **2,460 differing raw traces** across the paired
corpus because the adjacent chance/adjustment phases are still incomplete;
these differences are retained rather than asserted away.
