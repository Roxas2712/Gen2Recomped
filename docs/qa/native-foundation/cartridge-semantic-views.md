# Native Safari text and canonical metatile views

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

`core.game3.mb` shares the existing canonical native metatile namespace and
edition translators. It does not maintain another set of behavior IDs, alter
raw cartridge bytes or change collision/classification rules. This spelling
alone does not implement absent named metatile-label constants or door forecasts.

`Gen3SafariText` projects the current native Safari owner's imported IR through
`native.safari.<role>` keys. It validates the current edition/fingerprint and
native specification, returns detached nodes, and converts only the battle
placeholder representation to the existing formatter's namespace. Native IR,
prose, interpreter operands, rules, HP/AP, balls and RNG remain untouched.
Explicit text/prose edits and tombstones retain priority; translation remains
with the existing text service. There is no cache migration or replacement prose.

`battle.profile.of(view)` supplies a read-only Safari presentation view for an
actually admitted native Safari battle. Closing/replacing the battle, dataset,
source view or edition retires its fields. It does not advertise rule/action
or theme capabilities. Unsupported native owners expose no fabricated profile.
The source healthbox query delegates the Safari player's panel to the same
native counter painter used by the ordinary native HUD. The opponent panel and
source offsets retain their existing behavior. No second layout or ball counter
is maintained.

Fork source `555f68f87d` on main `c5766c86` passes 79 CPU groups, including
211 Safari text/profile/HUD checks, 225 shared text-pen checks, 807 collision
checks and 664 native text IR checks. Exact older-public composition
`f86529998d` passes 45 groups, including 659 IR checks and 8 negative
import/unsupported-owner/generation checks. That baseline lacks the later
native Safari owner; positive Safari controller/HUD qualification is not claimed.
The narrow helper remains dormant without that owner.

Untouched native Safari menu records retain the cartridge's compound word tag;
explicit record/prose changes and tombstones still take precedence. The shared
font pen renders its five native glyphs through the selected face's advances,
with an allocation-free exact-label path. Ordinary proportional labels and
existing text controls retain their behavior. The extractor accepts boolean IR,
fourth-slot options (including structured mode) and fifth-slot dialect options
without modifying caller tables. Latest-main cleanup and late provider writes
remain owned by their existing native stages.

Owned-output probes `1822c7cc9f` (fork) and `4fdd21da36` (older public) each pass
562 pixel checks across 240 frames on each of Metal and OpenGL. They cover
selected main/small faces, HD off/on, DPI1/2, scale1/2, indexed glyph identities,
pen controls, compound glyph order/positions and malformed input rejection.

The late-text fixture models required native UI stages' text writes rather
than trying to read absent stat/Safari ROM tables from a short synthetic string.
Actual final publication still owns the nativePlain snapshot. The old stages
are restored after the check. CI checks these observations plus existing Gen2
battle window/scene behavior.

Unchanged-mod FireRed Safari `549ab98f50` completes its native constructor,
paper view and idle cleanup. Its image exposed the ordinary player HP panel
where Safari balls should appear; that failure is retained as evidence and led
to the shared native-counter delegation. Corrected source `cb02fe24a7` run `69041aad74-firered` exits0 after all five
paper/native/terrarium/native/paper views and idle cleanup. Its inspected paper
frame shows the native Safari counter with30 balls instead of player HP.
The earlier Ruby `6e31b9e81d` completed five views but exposed clipped ordinary
lettering. Corrected Ruby `07392e9db4`, frozen from `555f68f87d`, exits0 after all
five paper/native/terrarium/native/paper views and idle cleanup. Inspected paper
and native images show the complete native compound glyphs within the menu and
the 30-ball counter; HP/AP remain unchanged through presentation switches.
Native throwing/reaction/capture parity, all-edition/all-map visual acceptance
and sustained60FPS are not inferred.

QA uses owned profiles, preserves player saves and enforces20GiB free, above
the requested8GiB minimum. Private mods and private runtime files are unchanged.
