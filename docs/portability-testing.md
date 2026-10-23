# Combined mod-portability testing branch

The fork's `codex/portability-testing` branch combines the public API, native
hook, rendering, shader and baseline test fixes prepared in PRs #88–159
(excluding unrelated #138). It is for testing the combined changes before
upstream reviews and merges the individual PRs. Upstream `main` is separate.

The combined runtime tested for this snapshot is
`2551b7ef641ad138dc78e03b6212e1e18da85702`. Its ROM-free run passed
167/167 engine suites, 3/3 SDK suites and the Dramatic Shape B30 profile.
The unchanged GBA field-item consumer passed both native effect dispatchers
in four SDK modes (16 worker runs / 250 paired observations). The new native
GBA suite passed 1,286 checks. Existing GB contracts also passed in all four
modes (24 workers / 339 paired observations). Follower, live-map, storage,
battle and party checks remain in the combined suite. See
`portability-testing-status.json` for each family's historical tested refs.

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
handlers and battle interception), and optional SDK services. Gen1's newer import verification
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

The recorded full-suite runtime includes the standalone GBA smoke driver.
Later commits only record validation and documentation. Older native smoke
families retain their own historical runtime refs; they are not relabeled as
new executions on this runtime.

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
