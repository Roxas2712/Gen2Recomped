# Unchanged consumer probes

These external acceptance drivers use the actual engine modules and unchanged
published mods. They are deliberately outside the ROM-free engine suite.
Run from an engine source checkout through a `qa_storage`-guarded launcher,
with LuaJIT and the supported imported **Red** dataset selected through
`POKEPORT_DATA_DIR`. Pin inputs before cache cleanup and run workers at nice 19.

- `read-only-qol.lua` takes the frozen QoL source directory, imported asset
  directory, `rectangle-glyphs`, and `qol-native-water.lua`, in that order.
  It maps read-only mod/art reads before executing the consumer.
- `battleart-native.lua` takes the verified package-source parent containing
  `battleart/` and `interiors/`, imported asset directory, `host` or `combined`,
  decoded-pixel fixture directory, and `pixel-hardware.lua`, in that order.
  It reads both packages unchanged, redirects persistence into memory, and
  refuses disk writes. No native callbacks or mod runtime methods are replaced.
- The pixel fixture contains `index.json`, mapping logical PNG paths to
  `width`, `height`, RGBA `file`, original `input_sha256`, and `rgba_sha256`.
  Decode pinned PNGs losslessly to RGBA. The accepted fixture covers imported
  tilesets/sprites/battle art, selected small package PNGs and the Interiors
  material/emission atlases. FileData names `interior-materials.png` and
  `native-emission.png` alias those same atlas records.

The pixel/mesh adapter validates CPU data. It leaves shaders and graphics-device
staging unavailable, and the battle probe explicitly checks the 2D fallback.
Neither no-op draw calls nor matching geometry counts establish visual equality,
shader validity, depth/reflections, FPS or handheld acceptance. The fixture's
ROM-derived pixels and third-party mod packages are not distributed here.

The formatted public probes have byte-for-byte identical stripped LuaJIT
bytecode to the successfully executed originals. See the adjacent
[acceptance receipt](../unchanged-mod-consumers.json) for refs, package SHA-256
values, raw log fingerprints, exact checks and remaining work.


## Native graphics drivers

`battleart-graphics.lua` and `battleart-graphics-battle.lua` run through the
engine's `POKEPORT_DRIVER` entry in an actual LÖVE 11.5 process. Set
`BATTLEART_GPU_OUT` to a fresh absolute QA output directory,
`POKEPORT_VERSION=red`, a new explicitly named QA `POKEPORT_IDENTITY`,
`POKEPORT_SKIP_LEGACY_MIGRATION=1` and `ALSOFT_DRIVERS=null`. Use a complete
frozen source tree including `tools/rom_manifest.json`, the verified unchanged
Battle Art/Interiors package combination and valid native imported Red data.
Pin all inputs and protect outputs/copies/profiles with `qa_storage` before
launching at nice 19. Never use normal player identities or portable mode.
If using a vendor app bundle, make sure an embedded `game.love` does not
silently replace the supplied source directory. A fresh private ROM import
must use the engine's regular importer, not a forged completion marker.

The first driver checks OFF/AUTO/FULL terrain, the lab, camera engagement and
logical free movement. Its doorstep third-person image is diagnostic only.
The battle driver validates a clear corridor, ready public stage, native
Fight/Surf/victory/PP/experience and stage release. It uses exported mod library
bridges and replaces no production engine/mod callback. Its action image does
not establish visual animation correctness. Inspect captures before claiming
appearance acceptance; the receipt retains UI, data-format and asset warnings.
Audio quality, physical controllers and performance remain outside this scope.


## Quit cleanup probes

`battleart-quit.lua` takes the verified package-source parent, imported Red
asset directory, and `host` or `combined`, in that order. It uses the real SDK,
Loader and quit bridge with hardware/persistence doubles; it checks actual
CompanionLifecycle cleanup and idempotence. No mod production code is changed.

`battleart-native-quit.lua` uses the same isolated native graphics setup above.
It renders FULL Pallet terrain, writes `before-native-quit.png`, installs an
observational wrapper and returns normally. The engine's driver completion
requests quit; the observer verifies the actual native quit dispatch and
package cleanup. It does not replace `love.quit` or the package disposer.
The accepted run exits zero and prints `QUIT_NATIVE_GPU_RESULT` with a false
exit decision, disposed companion and frame-wrapper count dropping from 12
to one. Check process completion and inspect the capture. This is not an
FPS, generic-unload or all-resource-disposal test.

The formatted probes have identical stripped LuaJIT bytecode to the executed
originals. The [quit receipt](../quit-to-launcher.json) pins original driver,
log and capture hashes and records standalone/composed scope separately.


## Native battle-style decision

`battle-style-native.lua` uses `POKEPORT_DRIVER` and the same isolated native
setup above with `examples/portable_battle_style` installed and enabled. Set
`BATTLE_STYLE_OUT` to a fresh absolute QA output directory. This driver needs
no Battle Art package. On Gen1, use a genuine regular ROM import into the QA
identity; loose generated data alone can leave the host in its ROM-required
launcher without executing the driver. Keep legacy migration disabled, audio
muted and the process at nice 19. Protect all inputs/copies/profiles with
`qa_storage` and keep normal saves/imports unchanged.

The driver constructs an in-memory trainer battle with a prepared one-HP lead,
then uses actual FIGHT/move input and the native result/ChoiceBox/send-out
queues. It checks forced SET, forced SHIFT with B/NO, and unsubscribe while
leaving the saved preference unchanged. Each ChoiceBox instance is counted
once across its normal answer hold. Four screenshots per run and a zero exit
are required. Three accepted runs have identical typed decisions/queue results;
the images retain each engine's native UI placement. This is not a complete
playthrough, artwork/pixel equality or FPS test. The formatted public driver
has identical stripped LuaJIT bytecode to the executed original.


## Cold dev-loader API modes

`dev-api-attribution-modes.lua` runs the engine's real
`tests/engine/mod_api_require_attribution.lua` with an API number, host-version
key and fixture-root path. From a composed engine checkout:

```sh
luajit docs/qa/consumers/dev-api-attribution-modes.lua 3 red .
```

The standalone upstream feature supports API 1/2; API 3 needs the earlier
shared API series in the composed branch. The harness parameterizes the six
actual serialized mod manifests, keeps the production loader/dev shim intact,
and checks coverage before the engine test's `T.finish` exits. All filesystem
activity stays in memory. Run via a `qa_storage`-guarded launcher at nice 19.
The public formatted driver has identical stripped LuaJIT bytecode to the
executed original. See the [receipt](../dev-api-attribution.json) for exact
host/API coverage, baseline failures, negative controls and native graphics
confirmation. Native confirmation reuses `battle-style-native.lua` unchanged.


## Native capture nickname decision

`catch-nickname-native.lua` uses the same isolated native graphics setup with
`examples/portable_catch_nickname` installed and enabled. Set
`CATCH_NICKNAME_OUT` to a fresh absolute QA output directory. Use a genuine
regular Red ROM import into the separate QA identity, disable legacy migration,
keep audio muted and launch at nice 19 through `qa_storage`. Do not use normal
player profiles or an embedded `game.love` that overrides the frozen source.

The driver creates in-memory party/PC state and prepared wild battles, then
uses actual ITEM, bag and Master Ball input. It verifies skip/direct party
name/direct PC name/forwarded YES and typed A/unsubscribe, exact one-ball spend,
original recipient identity, captured-event timing and ordinary battle return.
It also opens the native party menu to show the supplied name. Five captures
per engine are required and must be inspected. Host-native bag/naming layouts
are retained; rendered-pixel equality and full playthroughs are not asserted.
The public formatted driver has identical stripped LuaJIT bytecode to the
executed original. See the [receipt](../catch-nickname.json) for refs, hashes,
shared API coverage, retained setup failures and negative controls.
