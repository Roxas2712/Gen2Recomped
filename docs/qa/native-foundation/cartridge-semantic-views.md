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

Fork source `cb02fe24a7` on main `4e481a9c` passes 79 CPU groups, including
196 Safari text/profile/HUD checks, 807 existing collision semantics checks,
639 native text IR checks and the current native Safari rules/runtime suites.
Exact older-public composition `30716ff9f5` passes 44 groups: 807 collision,
576 IR checks and 8 unavailable-owner/retirement-boundary checks. It retains
its older native bodies and does not contain the later native Safari owner;
positive Safari controller/HUD qualification is not claimed for that baseline.
The narrow callback and shared helper remain dormant without that native owner.

The late-text fixture models required native UI stages' text writes rather
than trying to read absent stat/Safari ROM tables from a short synthetic string.
Actual final publication still owns the nativePlain snapshot. The old stages
are restored after the check. CI checks these observations plus existing Gen2
battle window/scene behavior.

Unchanged-mod FireRed Safari `549ab98f50` completes its native constructor,
paper view and idle cleanup. Its image exposed the ordinary player HP panel
where Safari balls should appear; that failure is retained as evidence and led
to the shared native-counter delegation. The corrected five-view visual run
is in progress. Full Safari throw/reaction/capture parity, all-edition/all-map
visual acceptance and sustained60FPS are not inferred.

QA uses owned profiles, preserves player saves and enforces20GiB free, above
the requested8GiB minimum. Private mods and private runtime files are unchanged.
