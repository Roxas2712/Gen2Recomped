# Combined mod-portability testing branch

The fork's `codex/portability-testing` branch combines the public API, native
hook, rendering, shader and baseline test fixes prepared in PRs #88–172
(excluding unrelated #138). It is for testing the combined changes before
upstream reviews and merges the individual PRs. Upstream `main` is separate.

The combined runtime tested for this snapshot is
`7a12243293dcb7a6ff2a00dc64490f3c6bb5aa32`. Its ROM-free run passed
192/192 engine suites, 3/3 SDK suites and the Dramatic Shape B30 profile.
[PR #172](https://github.com/UNDERdecoded/Gen2Recomped/pull/172) binds native
FireRed/Emerald party action text and separate cancel buttons, plus FireRed's
Item-PC withdrawal title, cancel row and submenu. Shared native reader checks
**257** and action/render/retirement checks **62** pass. The unchanged public
consumer compares through both real SDKs: **8 workers / 522 paired native text
values**, against clean Gen1 `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
Both API 3 and host API 2/unified pass, including wrong-profile isolation,
separate TAKE/CANCEL labels, control characters and existing-menu retirement.

Native LÖVE 11.5 / imported FireRed and Emerald pass at this runtime: actual
party/footer/submenu drawing, SUMMARY open/B-return, ITEM submenu/B-close,
party close; FireRed's real Player-PC → Item Storage → withdrawal title/list/
submenu and translated CANCEL without inventory changes. Isolated in-memory
New Game; no normal SAVE, full playthrough, fresh full-ROM import or pixel
identity claim. The owned example was removed with hash guards.
See [GBA menu prose](portable-gba-menu-prose.md).

All **32** hosted #172 workflows await maintainer approval (`action_required`);
the [GBA menu workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40076430839)
has zero executed jobs. Local validation is separate.

Prior #171 registry evidence below retains runtime
`62f8902617255195b4a12b176f171925c49209ec`; it is not relabeled as a new native run.

[PR #171](https://github.com/UNDERdecoded/Gen2Recomped/pull/171) adds a separate
engine-prose registry, native Gen-2 label projection/formatting, same-spelling
script isolation and ten native GBA Pokemon-storage action/description bindings.
Registry/native checks **175**, ownership **510**, formatting **57**, provenance
**52** pass. The unchanged consumer compares through both real SDKs:
**24 workers / 94 paired native observations**. The separate native formatter
comparison adds **8 engine workers / 96 paired observations**. All use the clean
Gen1 pin `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

At the recorded #171 runtime, native LÖVE 11.5 / imported Gold, FireRed and Emerald passed:
Gold native battle-prose helper, real textbox/end-marker handling and separate
same-label native script/A-close/resume; GBA actual storage menu/all five
labels/descriptions/B-close/reopen; frozen writes. This does not execute a
complete battle/wakeup turn. Isolated in-memory New Game, no normal SAVE,
full playthrough, fresh full-ROM reimport or pixel-equivalence claim. The owned
temporary example was removed with hash guards. See [portable ROM prose](api3-rom-text.md).

**Remaining prose work:** further party prompts, field-move names, mail/trade,
Item-PC quantity/results, Emerald Item-PC and other field/battle readers need
explicit bindings. A Gen-2 screen that still prints a hardcoded fallback
instead of reading its label also needs a native reader change. Availability
of `rom_text` does not mean every native printer or label consumer is covered.

At #171 publication, all **31** hosted workflows awaited maintainer approval (`action_required`);
the [ROM-prose workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40074003980)
has no executed jobs. Local validation is separate.

Prior #170 script-text runtime `a7a4091be9f4b631d54cd6f57ce1d33c5d8bed46`
and its native dialogue/grammar results retain their own status JSON fields;
they are not relabeled as new native script-text smoke runs. The existing
script-text unit contracts also pass in the current complete suite.

Prior #169 identity-hook native smoke and matrix results retain their own
runtime `19513a930c6befae0b0ee336d0c9f4984d7ae929` in the status JSON; they are
not relabeled as new native UI runs. See [Pokemon identity hooks](portable-pokemon-rolls.md).

Prior #168 mart, #167 held-definition and #166 scheduling evidence retains
its own historical refs in the status JSON. These establish their tested
contracts, not complete battle-rule parity; Choice Band locking, further
deferred abilities, Quick Claw turn-RNG ordering and volatile rules remain
separate work.

Prior held-read, field-residual, caught-marker, charge, PP, item, follower,
map and storage families retain their historical refs in
`portability-testing-status.json`; those results are not relabeled as new runs.

Native LÖVE 11.5 smoke tests reached the intro, title and New Game
world/introduction for Red, Gold, FireRed and Emerald using isolated copies
of existing imported caches. These prove startup, not full cartridge
playthroughs or universal mod support. Shared contract checks use clean pinned
Gen1 references; each `tools/*-contract-check/` tool documents its requirements.

## Start a test installation

```sh
git clone --branch codex/portability-testing \
  https://github.com/Roxas2712/Gen2Recomped.git gen2-portability-testing
cd gen2-portability-testing
bash scripts/run-portability-test.sh
```

Use LÖVE supported by the engine. If it is installed outside the locations
recognized by `scripts/run.sh`, set its executable explicitly:

```sh
POKEPORT_LOVE=/path/to/love bash scripts/run-portability-test.sh
```

The wrapper defaults to the separate LÖVE identity
`Gen2RecompPortabilityTesting` and disables automatic legacy save/settings
migration with `POKEPORT_SKIP_LEGACY_MIGRATION=1` and foreign save discovery
with `POKEPORT_ISOLATED_TESTING=1`. Import your own supported ROM through the
launcher, then install the mod under test in this test installation. No ROM,
generated cartridge cache, save or private mod is distributed by this branch.
The source checkout must be complete; sparse developer checkouts can omit
assets needed by the interactive launcher.

Keep the test game's data folder separate from normal installations. The
identity separates the initial save directory; choosing an existing game-data
folder explicitly can still share its files. Import a *copy* of a save through
the launcher when a test needs progress. See the normal launcher documentation
for supported versions and import requirements.

## Develop and verify

```sh
LUA=luajit bash scripts/test.sh --quick
```

For portable mods, start with API 3 and use `mod:supports` before optional
features. Keep generation-specific mechanics behind explicit capability
checks. See `api3-portability.md` and the `portable_*` examples.

The published PRs remove many adapter patches; they do not make arbitrary
engine-module imports portable. Remaining work includes DS party navigation, a shared follower-art contract, checkpoints, further
item/encounter hooks (including custom item effects, additional key-item
handlers, battle interception and a shared live table-transform seam), and
optional SDK services. LeafGreen/Ruby/Sapphire are not registered host profiles. Gen1's newer import verification
options also need a matching contract. DS native screens have additional gaps.
Shader imports intentionally support a bounded subset, not all RetroArch presets.

Feature changes continue as separately tested PRs. This testing branch will be
updated with tested combinations; it is not a replacement for reviewing them.

## Native boot smoke test

After importing a cartridge into the separate test installation:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_boot_driver.lua \
  bash scripts/run-portability-test.sh
```

The driver advances the native intro, invokes the title's New Game action,
checks the world below the introduction, and exits. It does not import or
copy a ROM itself. `POKEPORT_PORTABILITY_SHOT=/absolute/path/frame.png` can
request a captured frame. Use an isolated test installation; this driver
starts a new game and is not intended for your normal playthrough identity.

## Native battle-party smoke test

The fork also includes a bounded native menu test after cartridge import:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_party_driver.lua \
  bash scripts/run-portability-test.sh
```

Use the isolated identity and a disposable test installation. The driver starts
New Game, constructs six native Pokemon and a battle in memory, opens the real
party screen, enables the public navigation predicate, and checks direction,
submenu confirm/cancel and party cancel. It then exits. Red, Gold, FireRed and
Emerald passed with existing imported caches. Optional frame capture uses
`POKEPORT_PORTABILITY_SHOT=/absolute/path/party.png`. This smoke test does not
prove a full playthrough, native pixel parity or DS party-hook support.

The status file records a separate tested runtime ref for each native smoke
family, including the party-menu and storage-restart snapshots.

## Native storage restart test

Install the public `examples/portable_storage` folder as a mod in the isolated
test installation and enable it. With an imported cartridge, run two processes:

```sh
POKEPORT_VERSION=firered POKEPORT_STORAGE_PHASE=prepare \
  POKEPORT_DRIVER=tests/portability_storage_driver.lua bash scripts/run-portability-test.sh
POKEPORT_VERSION=firered POKEPORT_STORAGE_PHASE=verify \
  POKEPORT_DRIVER=tests/portability_storage_driver.lua bash scripts/run-portability-test.sh
```

Use a disposable test installation: `prepare` starts New Game and writes an
ordinary save plus mod records/bytes. `verify` resolves the selected storage at
the native title after a fresh launch, checks Continue and the binary/record
roundtrip, then deletes only the smoke keys. The ordinary test save remains.
Red, Gold, FireRed and Emerald passed both phases with the same installed
API-3 consumer. No generated cartridge data is distributed by this branch.

The current full-suite runtime includes the enemy-PP and caught-marker drivers.
Later commits normalize test-fixture formatting (verified bytecode-equivalent)
and record validation/documentation; they change no production code. Older native smoke families
retain their historical runtime refs; they are not relabeled as new executions
on this runtime.

## Native connected-map lifecycle test

Install and enable `examples/portable_live_maps` in the isolated test
installation, then run:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_live_maps_driver.lua \
  bash scripts/run-portability-test.sh
```

The driver starts New Game in memory, selects a bounded connected-town fixture
for Red/Gold/FireRed/Emerald, and uses the native map-loading and neighbor-rebuild
paths. It checks the same public consumer's preparing/updated delivery and API-3
pixel placements, including a repeated rebuild. It does not write a normal save
or distribute any cartridge data. Use the separate test identity; this is a
bounded lifecycle test, not a full cartridge playthrough or pixel-parity proof.
The consumer itself has no generation-specific map IDs or engine imports.

## Native follower lifecycle and movement test

Install and enable `examples/portable_follower` in the isolated test installation:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_follower_driver.lua \
  bash scripts/run-portability-test.sh
```

Red, Gold, FireRed and Emerald passed using the same installed public consumer.
The driver starts New Game in memory, selects a real town, verifies map-entry
allow/deny and original native handles, then sends native directional input.
It checks companion movement through the ordinary NPC/world update loop,
removal, respawn and unsubscribe. Map-load companions begin under the player,
so the fixture takes two steps to verify movement. The driver does not write
a normal save. Native smoke ref `0482e8473228da203f156e3d4c62e662393cdee0`
adds only this standalone driver over the follower full-suite runtime
`318a1bae110afd5a5ee892674b2e61dda9def98d`. DS follower
coverage and a shared follower-art API remain separate work; this is not a
full-playthrough or identical-artwork claim.

## Native GB item UI lifecycle test

Install and enable `examples/portable_item_use` in the isolated test installation:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_item_use_driver.lua \
  bash scripts/run-portability-test.sh
```

Red passed with imported native data and the unchanged public API-3 consumer.
The driver starts New Game in memory, opens the actual bag and party picker
with native input, blocks a Potion without HP/inventory/result-UI changes,
then delegates through healing, the HP animation and text back to the bag.
It also checks unsubscribe and native reuse. It does not issue normal SAVE.
Native smoke ref `3982554dc466ed3306b7a1256cac6c2f44a38cd1` adds only the
standalone driver over the historical GB full-suite runtime
`6775eabe22d77d89abd09d8ed4101c16b90a96b1`. The ROM-free shared tests cover
Red/Blue/Yellow in four SDK modes. GBA now has a distinct field-result producer;
this GB-shaped producer is not advertised for Gold/GBA/DS. These are bounded
native checks, not full-playthrough or pixel-parity evidence.


## Native GBA field-item lifecycle test

Install and enable `examples/portable_gba_item_use` in the isolated test
installation, then run with an imported cartridge:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_gba_item_use_driver.lua \
  bash scripts/run-portability-test.sh
POKEPORT_VERSION=emerald POKEPORT_DRIVER=tests/portability_gba_item_use_driver.lua \
  bash scripts/run-portability-test.sh
```

FireRed and Emerald passed on LÖVE 11.5 with the same installed API-3 consumer.
The driver starts New Game in memory, opens the real bag and party picker
with native input, blocks a Potion, delegates healing once, checks replaced
and suppressed result text after native HP animation, and unsubscribes. It
also uses the native white flute, verifies reusable inventory and the native
encounter modifier, preserves state on same-map reload and clears it on an
actual map change. It does not issue normal SAVE. The full-suite and native
runtime ref is `2551b7ef641ad138dc78e03b6212e1e18da85702`.

The two engines have different native item text and world services. This
proves the tested field-result boundary and bounded native lifecycle, not
all cartridge mechanics, UI pixel parity, a full playthrough or Gold/DS item
coverage. See `portable-gba-item-use.md` for the argument/result contract and
remaining native item adapters.


## Native title-screen encounter preview test

Install and enable `examples/portable_encounter_table` in the isolated test
installation. Run with an imported cartridge:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_encounter_table_driver.lua \
  bash scripts/run-portability-test.sh
```

Repeat with `gold`, `firered` or `emerald`. All four passed on LÖVE 11.5
using the same installed API-3 consumer. The driver reaches the native title
with no active overworld, chooses an actual imported map table, checks
replacement/empty/nil/unsubscribe, rejects RNG use during each query and checks
that native encounter tables, save and preallocated world identity stay
unchanged. It does not start New Game or issue normal SAVE.

Native ref `292c4beb6445ac09ee1541a68562a8fa9038f22f` and shared-report ref
`7b4e51dd479725a5c2797f0a1e46d9721e0189f9` add only this standalone driver
over the full-suite runtime. `encounter.table` is preview-only on both
engines: actual encounters still use `encounter.roll`/`encounter.species`.
DS does not advertise this hook. The shared fixture rejects unregistered
versions, including LeafGreen/Ruby/Sapphire, rather than silently testing Red.
See `portable-encounter-table.md` for the contract and generation boundaries.


## Native charge-turn resolution and queue test

Install and enable `examples/portable_charge_required` in the isolated test
installation, then run with an imported cartridge:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_charge_required_driver.lua \
  bash scripts/run-portability-test.sh
```

Repeat with `gold`, `firered` or `emerald`. All four passed on LÖVE 11.5
using the same installed API-3 consumer. The driver starts New Game in memory,
constructs native battlers with actual imported SolarBeam/Fly records and
checks charge/bypass, release without another callback/player PP cost,
GBA release animation metadata and unsubscribe. It uses the ordinary battle
state/input to consume the native text/result queue. This bounded test skips
the separate sendout intro and disables animation playback; it is not proof
of complete battle-entry, GPU animation, pixel parity or a full playthrough.
It does not issue normal SAVE.

The native ref is `e47c4ec558034c0b83b5f6ff5158510a79c3a459`; shared-report
ref `b5bc959d19b3d9e5ebc4528c9f47323bd35a0fbb` adds only the standalone driver
over the full-suite runtime. Native enemy PP costs are recorded separately:
Gold's reference spends one while this host's current Gen-1-default rules
spend zero. The new hook preserves that native policy; correcting the existing
rule difference remains work. See `portable-charge-required.md`.


## Automatic native rulesets and enemy PP

PR #162 fixes the measured Gold-family enemy PP difference for automatic
selection. New settings and cartridge-save import skeletons use RULESET -> AUTO
(`options.ruleset = false`). Explicit saved ids remain explicit; old literal
`gen1_faithful` settings cannot reveal whether the earlier default was intended.
Select AUTO to opt an existing test installation in. Gen 2 selects the bounded
`gen2_finite_pp` compatibility ruleset; this changes only enemy PP, not every
Gen-2 battle mechanic. See [native ruleset defaults](native-ruleset-defaults.md).

Install and enable `examples/portable_enemy_pp` in the isolated test installation:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/enemy_pp_defaults.lua \
  bash scripts/run-portability-test.sh
```

Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at the runtime above. The
driver starts New Game, preserves the existing preference check, selects AUTO
only in memory, and constructs a native wild battle with imported data. Real
FIGHT/move input drives three complete turn/result queues. The same public
observer checks PP; finite-PP games reach the native AI's Struggle fallback,
while Red retains unlimited enemy PP. An explicit Gen-1 choice is checked on a
new battle afterward. Sendout intro is skipped and animations are disabled for
this bounded queue check. No normal SAVE is issued; this is not a full-playthrough,
whole-battle or pixel-parity claim.

The standalone feature retains exactly the ten old baseline suite failures
covered by PRs #128–134 (115/125, SDK 3/3 and B30); this combined runtime includes
those repairs and passes all 170 suites. At #162 publication, all 23 hosted PR workflows reported `action_required` pending maintainer
approval; the [PP workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40046010257)
had zero jobs. Those recorded results are separate from local validation.


## Native caught-marker HUD/GPU test

PR #163 adds `battle.caught_marker_visible` and its actual classic/wide GB and
GBA single-battle marker rendering. Gen 1 defaults off; Gold/GBA default on for
eligible already-caught wild species. Only literal true shows it. Ownership,
trainer/tutorial/ghost/status/hidden-HUD gates and GBA presentation caching
remain native. DS reports unavailable. See [portable caught markers](portable-caught-marker.md).

Install and enable `examples/portable_caught_marker` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/caught_marker.lua \
  bash scripts/run-portability-test.sh
```

Imported Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at native runtime
`40e3e1219e05dd3f675fddcc01c7b1b0f92593ab`. The driver starts New Game,
constructs a native battle and draws the actual HUD into GPU canvases. Pixel
readback checks show/hide/native/nil/zero, ownership/trainer/status/hidden-HUD
exclusions and unsubscribe with the same installed API-3 consumer. Optional
`POKEPORT_CAUGHT_SHOT=/absolute/path/hud.png` writes an inspected HUD image.
No normal SAVE is issued. This is bounded native HUD/GPU verification, not a
complete playthrough, full battle sequence or cross-engine pixel-equality proof.

The GPU smoke uses existing cache artwork/fallbacks. The older Emerald glyph
is cropped to its native 8x8 footprint. Fresh GBA imports now read tile 70
separately from the unchanged 66-tile status scan; synthetic ROM bytes exercise
the real reader/decoder and output palette/transparency. Complete fresh-ROM
reimports were not performed. The later full-suite runtime includes this
import-reader correction; it is not relabeled as a new GPU execution.

Feature full-suite ref `bd182e0f4c39df69f86bcc76ceb15a51e1330579` passed
118/128 engine suites with exactly the ten old baseline failures covered by
#128–134, SDK 3/3 and B30. The combined runtime includes those repairs and passes
173/173. The feature head's later change is bytecode-equivalent fixture formatting;
the native contract suite was rerun afterward.


All 24 hosted #163 PR workflows currently report `action_required` pending
maintainer approval; the [new caught-marker workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40048498745)
has zero jobs and has not executed. Local test results above are independent.


## Native field-residual input and faint/replacement test

PR #164 adds `battle.field_residual` on GB/Gold/GBA. Mods read detached field
and battler data and return validated damage descriptors; native code owns
HP, messages, animation, faint events, EXP and replacement. GBA supplies slot
IDs 0–3, once-per-turn dispatch and stale-batch refusal. DS reports unavailable.
See [portable field residuals](portable-field-residuals.md).

Install and enable `examples/portable_field_residual` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/field_residual.lua \
  bash scripts/run-portability-test.sh
```

Imported Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at runtime
`8e0d34aeee4328465155bb2ea884145e2dcc40ec`. The driver starts New Game,
constructs native battles and drives actual FIGHT/move input through the
normal result queues. It then verifies detached edits, both orders of
simultaneous final KOs and unsubscribe. GBA additionally checks a right-flank
KO through native EXP and replacement, and simultaneous terminal doubles.
Gold retains both terminal faint announcements; GB/GBA suppress the enemy's
faint/EXP path. The driver stops at the in-battle loss before finish/blackout
or SAVE processing. This is not a full playthrough or whole-rule/pixel parity
claim; sendout intros are skipped and animations disabled in memory.

The unchanged consumer passes the actual reference GB/Gold/GBA producers and
the host in API 1 native, API 2 native, API 2 unified and API 3 unified modes:
64 isolated workers and 568 paired observations. Tests cover native weather
upkeep, batches/clamping, failures/replay, detached views, GBA Psychic type
pairs/flanks/once-per-turn/stale state, allied own-party authority, terminal
single/double KOs, unsubscribe, no-mod and entry rollback. The reference GBA
collector records residual steps; these comparisons do not run its complete
presentation/award controller. The host authority suite separately drains
real native EXP/faint/replacement queues.

Feature ref `124da70a77a09737d6a99aef2933ab722b3d5133` passed
120/130 engine suites, SDK 3/3 and B30, with exactly the ten prior baseline
failures covered by #128–134: all 26 FAIL lines match the previous #163 run.
Imported Red battle/save-conversion/parity J/K checks passed
468/468, 95/95, 73/73 and 22/22 respectively; external binary save fixtures
were not supplied. The combined runtime includes the baseline repairs and
passes 175/175 engine suites. Later testfork edits only record this evidence.

All 25 hosted #164 PR workflows report `action_required` pending maintainer
approval. The [new field-residual workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40050804974)
has zero jobs and has not executed. Local validation above is separate.


## Native held-item input, consumption and entry/escape test

PR #165 adds `held_item.trigger` on Gen2/3 hosts. It steers actual native
held-effect reads with common `HELD_*` names, two-result forwarding and byte
probability parameters. API 3 exposes common item/Pokemon identities and
scalar definition transactions; Gold metadata edits persist and GBA's remain
per-read copies. GB/DS report unavailable. See
[portable held-item reads](portable-held-items.md).

Install and enable `examples/portable_held_item` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/held_item.lua \
  bash scripts/run-portability-test.sh
```

Imported Gold, FireRed and Emerald passed on LÖVE 11.5 at runtime
`3d6bfceeaf25b97d7a7ce708ada8fe3306e0357d`. The driver starts New Game,
constructs native battles and drives actual FIGHT/move input and result
queues, checking public imported IDs, suppression/substitution, HP and held
consumption. It verifies native delegated Leftovers, one-HP endurance and
unsubscribe; GBA also exercises entry White Herb and the actual RUN menu.
The in-memory setup skips sendout intros and disables animations. It stops
before battle finish/afterBattle/SAVE processing. This is bounded native
verification, not a full playthrough or cross-engine pixel proof.

The unchanged consumer passes both real SDKs on Gold/Silver/Crystal and
FireRed/Emerald in API 1 native, API 2 native, API 2 unified and API 3 unified:
40 isolated workers and 1,706 paired observations. Tests exercise native
readers and actual moves/order/entry/escape/residual handlers, all 66 GBA
enums through the real item-data fallback reader, errors/replay, metadata,
no-mod and rollback. Native HP formulas are checked for the requested effect,
not asserted identical. The source GBA residual collector is not its complete
presentation/award controller.

At the #165 runtime, the worker separately recorded unrestricted empty-hand
grants under `native_policy`: reference GBA read six times and healed 35 HP
for a 7-HP Berry override, versus two reads and 7 HP in the host. That gap
was excluded from equal observations and rejected by the strict checker.
PR #166 resolves this historical discrepancy; unchanged #165 remains a
negative control. The unchanged pre-hook #164 engine also reports unavailable,
dispatches zero callbacks and cannot suppress native Leftovers. Full Choice
Band locking and other native battle rules remain additional work.

Feature ref `1ce83faf4b980584be9d747eee82efc530ede09f` passed
122/132 engine suites, SDK 3/3 and B30, with exactly the prior ten baseline
failures repaired by #128–134; all 26 FAIL lines match #164. Imported Red
battle/save-conversion/parity J/K regressions passed 468/468, 95/95, 73/73 and
22/22; no external binary save fixture was supplied. The combined runtime
includes those baseline repairs and passes 177/177 engine suites. Later
changes only record this validation.

All 26 hosted #165 PR workflows report `action_required` pending maintainer
approval. The [new held-item workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40054092842)
has zero jobs and has not executed. Local validation above is separate.

## Native GBA item-scheduling test

Install and enable the unchanged public `examples/portable_held_item` mod,
then use the isolated installation with an imported FireRed or Emerald:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/drivers/held_item_scheduling.lua \
  bash scripts/run-portability-test.sh
```

The driver starts New Game in memory, builds a native battle, chooses FIGHT
and a move through native input, and drains the normal result queue. It checks
bounded empty-hand grants across a full turn, poison cure before lethal chip,
consumption and unsubscribe. It does not write a normal save or prove a full
playthrough. Gold uses the existing `tests/drivers/held_item.lua` smoke.

## Native held-definition test

Install and enable `examples/portable_held_content` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/held_content.lua \
  bash scripts/run-portability-test.sh
```

The driver uses an in-memory New Game and constructed native battle, actual
FIGHT/move input and result queues. It checks imported public item IDs,
7-HP healing and consumption, detached reads and frozen writes, then stops
before finish/afterBattle/SAVE. This is not a full-playthrough or pixel test.
Keep this example separate from the older `portable_held_item` example when
checking unmodified native behavior.

## Native mart-definition test

Install and enable `examples/portable_mart_content` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/mart_content.lua \
  bash scripts/run-portability-test.sh
```

The driver starts an in-memory New Game, compiles bounded native shop IR,
runs real script coroutines and uses actual menu input. It verifies imported
public IDs, ordinary and bargain prices, money/inventory, sold-out and reopen
protection, runner close/resume and detached/frozen public records. It exits
without a normal SAVE action. It does not claim a full playthrough, fresh full
ROM reimport, daily stock reset or special-shop pixel equivalence. Old imported
marker-only fallbacks need reimport for the new mart-ID annotations; the
normal ROM-script path uses the live pool directly.

## Native Pokemon identity-hook test

Install and enable `examples/portable_pokemon_rolls` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/pokemon_rolls.lua \
  bash scripts/run-portability-test.sh
```

Gold, FireRed and Emerald pass. The driver starts an in-memory New Game and
uses imported species metadata, real constructors, native summary creation/
drawing and B-close input. It checks common API-3 IDs, Gen-2 refresh, GBA
cached display/live query distinction, unchanged genes/stats under plain
overrides, the native forced-wild constructor and callback bypass, then
retires the callbacks. It does not perform a normal SAVE action or claim a
complete battle/playthrough, raw save-format or pixel equivalence. Deliberate
Gen-2 DV edits are a separate mutation case in the shared contracts.
