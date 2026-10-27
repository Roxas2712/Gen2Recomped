# Native GBA integration

The delivery target is the source of `Roxas2712/Gen2Recomped`, including its
normal import and packaging paths. The separate private companion application
is a local test and distribution input; it is not the acceptance target.

## Included changes

- Ruby/Sapphire edition identification, original intro/title and soundtrack
  roles, Birch/naming/starter and Wally sequences, native main menu,
  bag/party/summary/PC/Pokédex/PokéNav/shop/clock/mail presentation and host
  transaction callbacks.
- Ruby/Sapphire field palettes, terrain and bicycle predicates, ferry/cable-car
  transitions, flash and weather layering, wild encounter arithmetic and
  buried trainer visibility.
- FireRed/LeafGreen original intro/title, main-menu layout, trainer identities
  and edition-specific dialogue-frame/font geometry.
- Emerald original movie and Rayquaza title, verified resource readiness and
  cartridge-specific audio bindings. Remaining Emerald menus and professor
  presentation are not claimed to match the cartridge yet.
- Shared GBA binding damage, drain accounting, self-stat costs, secondary
  effect protection, native START rendering/paging and cursor retention.
- Rusturf's native two-rock pair, opened-tunnel guard and one-time HM04 reward.
  Other saved-rock objects cannot disable this puzzle.
- Edition-local sound-program caches and launcher badge summaries.

Existing Gen2 native party, summary, battle PACK and move-selection owners,
DS link revisions, X/Y integration and newer launcher/account fixes remain
part of the fork. This integration does not revert those changes.

## Reference provenance

The isolated Hoenn and FR/LG presentation bridges use individually hashed
sources from Gen1Recomp revision
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b`.
See `compat/gen1-rs/provenance.json`, `compat/gen1-frlg/provenance.json` and
the licences retained in each `reference/` directory. The original launcher
is excluded. ROMs, generated graphics/audio, player saves, private run logs
and application bundles are excluded from this contribution.

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp). The surrounding fork retains
Cedric / UNDERdecoded's and all other applicable notices and licences.

## Verification boundaries

Before this public-source integration, isolated native runs accepted all five
edition entry paths on the preceding gameplay branch. R/S entry fixtures used
prepared native main-menu saves; FR/LG and Emerald runs covered their original
movie/title sequences, audio, new-game entry and save/continue. Separate native
fixtures exercised all-five START and battle fixes, and R/S/E Rusturf reward
and re-entry behavior.

An ordinary Sapphire playthrough completed the repaired Rusturf HM04 scene,
returned to Petalburg, defeated Norman and saved the fifth badge and TM42
normally on the public integration source. It then obtained HM03, taught Surf
through the native bag/party/summary flow, healed normally and tested mounting,
water movement and dismounting. The complete saved state survived the original
CONTINUE menu unchanged. These are checkpoints, not a
full-game acceptance. Complete ordinary stories, endings,
postgame systems and the remaining per-edition presentation gaps are still
open for all five editions. No overall completion percentage is asserted.

The merged public tree must pass its own checks before these earlier results
are treated as regression evidence. Run the repository engine and mod-SDK
suites, focused GBA contracts and native entry fixtures against that tree.
Native checks require the player's verified cartridges and an isolated QA
profile. `tools/run_edition_native.py` and `tools/run_lua_contracts.py` use the
repository's guarded storage workflow. Cache reuse is allowed only when its
extraction input hashes match the tested source.

The public main integration's 684 engine suites passed on Linux, as did all
four mod-SDK suites, the
five-edition entry/cursor matrix and FR/LG dialogue-frame checks. The latter
compare 2,944 pixels per edition with its own cartridge. The final renderer
guard also passed native RS shop transactions and camera/save immutability.

The pinned Gen1 secondary helper has two documented cartridge-rule gaps.
The cross-engine checker retains its raw equality result and separately
audits the corrected expected cartridge behavior; see the
[secondary oracle](../tools/enemy-action-contract-check/secondary-oracle.md).
It preserves strict comparisons of damage, RNG, identities and all other
observations, and does not patch the read-only reference.

The standard `scripts/pack_love.sh` and `scripts/build.sh` include `compat/`;
normal source builds therefore contain these bridges without requiring a
private application payload.

Ordinary story QA may resume a witnessed normal-menu save after its isolated
window exits cleanly before the driver's final command. It requires an unchanged
frozen source, exit code zero, no importer failure or timeout, no unrecorded
inputs and no progress after the saved receipt. The original unfinished run
remains unfinished; the new run must independently verify the full saved state
through CONTINUE. Crashed, timed-out and unproven runs remain ineligible.
