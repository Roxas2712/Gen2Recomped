# Pokémon X/Y · Recompiled Ascendant

Native integration by **Roxas2712**, using fearkov's separately licensed
Zakuro and 3dsrecomp (MIT). X/Y use compiled ARM-to-native libraries inside
the fork's LÖVE window. The earlier private gameplay evidence is retained
below; it does not qualify each subsequent packaged runtime automatically.

## Start

Fresh profiles show **3DS · X / Y (Beta)** before an import exists. Open an
edition and choose **Import game** (`.3ds`, `.cci`, `.cxi`, `.cia`), or drop a
3DS file onto the library to detect its edition. Import streams the complete
hash and verifies the decrypted executable/content headers. A wrong edition,
damaged dump or encrypted content cannot replace an existing entry. Currently
the supported base-game title IDs are `0004000000055D00` (X) and
`0004000000055E00` (Y). The archive's region label is not a compatibility check;
the importer verifies the actual cartridge headers and content hashes.
The original local file is referenced in place; keep it available at that path.
Import does not upload it, copy a multi-GB ROM, or mark an unbuilt game playable.
LÖVE 12 uses its attached asynchronous native file picker for X/Y, so the
launcher keeps updating while the dialog is open. Cancellation changes no
import; overlapping selections and callbacks for a different edition are ignored.

The bundled **macOS Apple Silicon** demo includes its native bridge, recompiler,
Python, Zig/Clang, Vulkan Loader and MoltenVK under
`Contents/Resources/3ds-runtime`. This 3DS graphics bundle requires macOS 15+.
End-user imports need no developer checkout, Rust, Homebrew or Xcode.
With this bundle, **Import game** automatically validates the file, compiles
the game, runs the existing device qualification and opens it. The first import
can take a while; the launcher displays compilation counts. Existing imports
can use **Prepare game** to perform the same preparation and play handoff.

Helpers are extracted into the writable `pokemon-xy-backend` directory under
the app profile. ROM references, builds, settings and saves remain there or at
the selected original file path. Python bytecode and compiler caches never
write into the signed application. A build is reusable only after an atomic
completion marker records its ROM, compiler identity and library digest;
interrupted or changed binaries must be rebuilt. Driver updates invalidate the
device qualification separately from the game compiler cache.

The compiler wrapper suppresses Zig's default generated DWARF with `-g0` while
retaining the recompiler's `-O2` and precise floating-point flags. This avoids
large duplicate debug objects in the build and its bounded compiler cache.
Its wrapper digest participates in the game-build identity. The default is
two compiler jobs; maintainers may set `RETRO_3DS_BUILD_JOBS` to 1–8 for a
measured build on their own host. Invalid values fall back to two jobs.
After a confirmed link, byte-identical compiler-cache object copies can be
retired. Zig's local manifests are preserved outside its lookup path first, so
a subsequent compile cannot resolve a removed cached object. The ROM-free
`tools/qualify_pokemon_xy_cache.py --runtime <sidecar>` exercises this complete
compile/link/retire/rebuild cycle with the real bundled compiler.

A bare `.love` without the sidecar still supports file import but needs an
installed backend before playing. Developer overrides are `POKEMON_XY_ROOT`
(workspace), `POKEMON_XY_RUNTIME_ROOT` (reviewed sidecar), and optionally
`POKEMON_XY_PYTHON`. No ROMs, generated game libraries, console keys, firmware,
private player data or private intro artwork are included in the runtime.
Other 3DS platform binaries remain unqualified.

### Windows x64 bundle

The Windows demo builder stages the game-data-free SDK as `3ds-runtime/`
beside `RetroRecomped.exe`. It contains native PE x64 3dsrecomp/bridge binaries,
Python 3.12, LLVM-MinGW Clang, a Vulkan loader and an additional Mesa/Lavapipe ICD.
The ICD is added alongside system drivers; a capable hardware GPU is preferred.
There is no end-user Visual Studio, Rust or Python installation step.
Initial guest compilation uses two compiler jobs and the existing per-ROM
completion/hash marker. Existing ROM references, settings and player folders
remain in the selected profile. A Mac-generated dylib cannot be reused as a
Windows DLL; preparing its native code does not reset the player's data.

`tools/build_windows_native_runtime.py --out <fresh-QA-candidate> --graphics`
builds the pinned components on Windows. `windows-native-games.yml` runs this
and the isolated `qualify_windows_native.py` checks. Component reuse requires a
successful original run, exact file inventory and unchanged native source trees.
Packaging refuses a missing/failed native report or stale source binding.
See [the Windows demo evidence](qa/windows-cloud-demo-20261030.md) for actual
tested scope. ABI, synthetic ARM11/Vulkan/snapshot checks and played Pokémon
sessions are reported separately; a packaged SDK alone is not gameplay proof.

Maintainer builds use `tools/build_pokemon_xy_runtime.py --fetch-components
--build --test --out .local/qa/3ds-runtime-package-<run>/source`. Install the
maintainer Rust 1.95.0 toolchain in `.local/pokemon-x/cargo` and
`.local/pokemon-x/rustup` first; the output bundles no Rust toolchain. Source
revisions, patch hashes and dependency archives are pinned in
`tools/pokemon_xy_source_pins.json` and `tools/pokemon_xy_components.json`.
Existing unrelated dependency edits are preserved and rejected for release
builds. `tools/package_pokemon_xy_runtime.py` verifies the complete inventory
before embedding it in a new app; sign the containing app afterward.

`tools/qualify_pokemon_xy_runtime.py --runtime <sidecar>` relocates the runtime
into an app-shaped folder with spaces, masks system developer tools, compiles
and executes a ROM-free C library, checks the bridge ABI, creates a real Vulkan
instance/device, and verifies the sidecar remains byte-identical. This is
runtime/toolchain qualification. A genuine X/Y import and played session are
separate acceptance tests requiring the tester's own decrypted dump.

The 2026-10-27 macOS bundle passed relocation, bundled C compilation, native
bridge loading and Vulkan device enumeration on Apple M2. The real LÖVE import
worker also rejected an intentionally non-executable synthetic NCCH file while
preserving its imported metadata and showing an explicit build error. Worker
completion uses a terminal protocol record because LuaJIT's process-close
status alone is insufficient on this host; a missing record fails closed.
Genuine X/Y dumps were subsequently validated and compiled privately with the
debug-free bundled compiler. Separate instrumented app copies exercised cached
import through the normal device gate and visible native gameplay: German
language selection, intro and prologue. The Y run included five minutes of
native play. No ROM-derived C, native game libraries or private save profiles
are distributed. This is a bounded first-run test, not a full-game, battle,
3DS cloud-transfer or online compatibility certificate. See
`docs/qa/pokemon-xy-bundle-20261027/native-game-qualification.json` for the final
scope, and the separate runtime/cache reports for ROM-free qualification.

Open `Start-Recompiled-Ascendant.command` for the shared library, or
`Start-Pokemon-X.command` / `Start-Pokemon-Y.command` for a direct edition
start. The private runtime and game libraries live in `.local/pokemon-x/`.
The 3DS system tile is in the second system row; X/Y use ordinary collection
cards, favorites, readiness counts, 3DS cartridge shapes and live previews.

Each start prepares/qualifies the backend and plays the usual cartridge launch
animation. Development workspaces with the private intro assets then play
the full **Recompiled Ascendant · by Roxas2712** intro.
Rolling Poké Balls and the full opening chime precede Lugia's cry and sweep.
The scene ends at 13.1 s and hands off to the game in the same window.
There is no OmegaDias/eye continuation. Input can skip; the existing animation
preference can disable the sequence. Direct edition starters play it once.
Packaged runtimes without that private asset pack enter the game after the
ordinary cartridge sequence.

## Screens and window usage

All layouts remain user-selected: gapless stacked screens, side-by-side,
large main + small touch screen, docked/floating touch overlay, top only or
bottom only. In overlay mode the touch screen defaults to the right of the
main image, without covering it. Choose left/free placement in the launcher
or pause menu; drag with the right mouse button or Alt + left drag. Overlay
size and placement persist per edition after returning to the library.

“Leeres Touch-Bild ausblenden” is optional and defaults on. It detects a
fully black framebuffer or the exact neutral X/Y diagonal background,
including 1×..8× render variants. It releases the space reserved for the
lower screen in dual layouts too. Unknown/modified backgrounds and images
containing other content remain visible. It does not guess cinematics from
motion or crop game art automatically. Explicit bottom-only view stays usable.

Window usage offers original proportions, a proportional crop to fill the
window, and stretching to fill it. Crop can remove edge content; stretch
changes proportions. The choice is explicit and reversible. Stereo choices
are off, red/cyan, side-by-side, half side-by-side and interlaced, with depth
0–100% and eye swap. Real binocular separation requires a matching display
or glasses; software cannot give an ordinary display that optical property.

## Input

| Action | Keyboard | Standard SDL controller |
|---|---|---|
| 3DS A / B / X / Y | X / Z / S / A | A / B / X / Y |
| D-pad | Arrow keys | D-pad |
| Circle Pad | I / J / K / L | Left stick |
| L / R | Q / W | Left / right shoulder |
| ZL / ZR | 1 / 2 | Left / right trigger |
| Start / Select | Enter / Backspace | Start / Back |
| Recompiler menu | Escape | L3 or Guide |
| Touch | Left mouse button | Right stick + R3 |
| Save / load quick state | F5 / F8 | Pause menu |
| Touch overlay / top | F6 | Pause menu |
| Gapless dual / top | F7 | Pause menu |
| Cycle layouts | F9 | Pause menu |
| Top / bottom only | F10 | Pause menu |
| Fullscreen | F11 | Window control |

The pause menu supports D-pad up/down, A to activate and B to resume. Start
and Select remain game buttons. Controller mapping and touch/menu behavior
have synthetic HID tests; physical controller models are not certified.

Native software-keyboard requests open a form in the same window. Type text
directly, or choose letters with controller D-pad/A; B deletes, X changes
case and Start confirms. Game input is held back while the form is open,
including held controller buttons when returning. The backend validates the
game's requested text limits. Actual late-game naming flows remain to be tested.

The confirmed first-run game language is remembered immediately, separately
for X and Y. On a subsequent fresh boot, only exact recognized first-run
language screens receive the stored selection/confirmation. Unexpected
screens stay manual. “Sprachauswahl zurücksetzen” parks only this preference;
no save is deleted or patched. A game save's own fixed language remains
controlled by the game; resetting this helper does not translate an existing
adventure. Preferences and saves share a stable per-player data root, while
previews and QA use independent profiles.

## Mods

Import a folder or ZIP containing `romfs`, `romfs_ext`, `textures`, `exefs` or supported
code-patch files. X and Y have separate mod folders. Imports reject traversal,
symlinks, collisions and packages over 2 GiB and respect the 20-GiB reserve.
Existing files are never overwritten. The whole installed set can be parked
and re-enabled without losing its bytes. Texture-pack loading is selectable.
The private visible testmod changes only two English/German professor greeting
lines to “ASCENDANT TESTMOD: AN”. `tools/pokemon_xy_testmod.py` builds tiny BPS
file patches from the user's own dump; source CRCs reject mismatched archives.
No game files are bundled in the tool. The Y off/on/off native 3× test reproduces
the original image byte-for-byte after disabling the mod. Private X/Y testmod
packages are installed but parked by default; use the ordinary mod toggle to
enable them for a fresh introductory sequence.

No third-party gameplay mods are bundled or fetched. Modified executable code
may use the backend's interpreter fallback or need another recompilation.
The older games' Lua/Origami Cards are not automatically Gen-6 mods.

## Qualification and limits

The native gate requires AOT + GPU, warms up 120 emulated frames and measures
360 frames. A profile passes at full emulation refresh (~59.83 Hz) and p95
frame work ≤33.4 ms. If the requested resolution fails, 1× is tested before
“Device too weak” blocks the launch. Missing backend support is a separate
error. Results are tied to backend, ROM, graphics and mod fingerprints.

This is a **startup qualification**, not a sustained gameplay/thermal test or
a promise of 60 game-rendered FPS. X/Y can draw on every other emulated refresh.
The fork displays stage timing when FPS diagnostics are enabled. Presentation
uses bounded frame queues and reusable ImageData buffers, copies directly from
native memory and retains unchanged images instead of uploading them again.

The extended early-Y check now covers 47.93 minutes across five window runs
(including dialogue/idle), starter selection, the first trainer battle and two
replays from the tester's own state, plus house/Vaniville/Route 1/Acquacorde
transitions. The final warm battle replays sustain about 59.7–59.8 emulated Hz
at 3× with stereo off. Earlier foreground transitions still include 0.31–0.57 s
native pauses; background stalls are reported separately. This is therefore
not a blanket smoothness pass. It does not qualify wild battles or later areas.
The normal user's four savedata files remained byte-identical after the tests.
The subsequent transition optimization reuses retired native readback snapshots
and avoids small compiled shader handoffs on macOS. Its controlled A–B–B–A
retest shows about 7% less observed native frame work and no recurrence of the
large earlier stalls on the tested route. The controls also did not reproduce
those stalls, so complete causal elimination is not proven. See
`qa/pokemon-x-feasibility-20261026/transition-optimization.md` for the exact scope.

Build/check evidence and measured scope are in
`qa/pokemon-x-feasibility-20261026/README.md`. Mobile, iOS, Android and Switch
binaries, driver/JIT/AOT permissions, touch integration and thermal limits are
not qualified by this Mac run. No minimum phone/Switch specification is claimed.
ROMs, decrypted data, generated game C/libraries, private assets and saves stay
outside Git. Third-party licence notices remain with their source/runtime.

ROM-free regression checks run with `python3 tools/run_pokemon_xy_contract.py`
(LuaJIT and Lua 5.4 required). Pass `--bridge /absolute/path/to/the/reviewed/bridge`
to also check native layout and synthetic controller HID; this does not launch a
game. CI runs the portable checks without private ROMs or native dependencies.
