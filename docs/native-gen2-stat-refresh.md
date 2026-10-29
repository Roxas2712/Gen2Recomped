# Native GSC stat refresh

Implementation is on `codex/native-gen2-stat-refresh`. Corrected source
`273692e8` passes the selected qualification below; full-tree and GPU/release
acceptance remain open. This is an engine change, with the mod and player instances
unchanged. It does not complete the standalone source battle model or the
remaining source Mon API.

The source Mon contract at frozen Gen1 revision
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` exposes `stats`, `hpDV`,
`refreshStats(mon,data)` and `syncIdentity(mon,data)`. The native adapter
lacked the first three and inherited a native identity method with reversed
arguments. `Stats.ensure` is a different operation: it preserves existing
party stats, while the source refresh recalculates them on summary entry.

One native `Stats.calcGen2` now calculates the GSC stat block for both the
shared engine and source API. The HP DV follows the four actual genes, with
stale stored HP ignored. Both special stats share the Special gene and stat
experience; older source split keys remain input fallbacks. The cartridge
ceiling square-root loop is capped at255 before quartering. Gen1 and Gen3
keep their existing independent calculation branches.

The native Pokemon owner recalculates an existing block and refreshes its
identity, preserving wounds/fainted zero and initializing only missing or
excessive HP. Derived fields remain bound to the actual native tables.
Explicit older stored name/type copies are refreshed too. The public source
argument order is translated explicitly. Original GSC Unown refreshes its
DV-derived letter; the separate later form owner is retained.

Actual native summary construction uses the refresher. Live native battlers
whose current stats shared the old party block follow its replacement;
a separate Transform/current override remains separate. This binding uses
weak native owners, without adding a helper field to saved Pokemon, creating
a second Pokemon, running a presentation clock or retaining ended battles.

The pure probe covers all 65,536 gene combinations for HP derivation, sampled
full-stat vectors against an independent integer square-root search, legacy
fallbacks and Gen1/GBA guards without LOVE. A separate actual SDK/summary
probe covers native identity, replacement, shared/transformed combat inputs
and wounded/fainted HP. On source `273692e8`, all 185,360 data checks and 238 actual SDK/native
checks pass. Existing summary326, identity142/7232/5290, field184/177/100,
battler691/972, battle-checkpoint1387 and save-summary50 regressions also
pass. On predecessor main `152e2372`, the exact new fixtures fail the missing
formula check and all three native signature/refresher checks. These are
actual independent frozen-host positive and negative runs. Complete
full-tree and unchanged-mod GPU/release acceptance remain open.

Native integration and tests by Roxas2712 follow `LICENSE-ROXAS2712.md`.
Existing engine authors' rights and notices remain effective.
