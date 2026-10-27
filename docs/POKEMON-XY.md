# Pokémon X/Y · Recompiled Ascendant

Private macOS/arm64 integration by **Roxas2712**. Both own USA dumps have
compiled ARM-to-native libraries and run through Zakuro inside the fork's
LÖVE window. This is an embedded native backend, not a Gen-6 reimplementation
of the older games' Lua engine. Existing native Lua games keep their owners.

## Start

Open `Start-Recompiled-Ascendant.command` for the shared library, or
`Start-Pokemon-X.command` / `Start-Pokemon-Y.command` for a direct edition
start. The private runtime and game libraries live in `.local/pokemon-x/`.
The 3DS system tile is in the second system row; X/Y use ordinary collection
cards, favorites, readiness counts, 3DS cartridge shapes and live previews.

Each start prepares/qualifies the backend, plays the usual cartridge launch
animation, then the full **Recompiled Ascendant · by Roxas2712** intro.
Rolling Poké Balls and the full opening chime precede Lugia's cry and sweep.
The scene ends at 13.1 s and hands off to the game in the same window.
There is no OmegaDias/eye continuation. Input can skip; the existing animation
preference can disable the sequence. Direct edition starters play it once.

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
