# RetroRecomped library shell

The implementation starts from the fork's `main` at `13af468b` on
`codex/retro-launcher-layout`. The Gen1 launcher's immediate-mode menu structure
was inspected as a usability reference; this shell adds its own layout,
hardware illustrations, editor and intro sequence.

## Behavior

- The library opens first. Console, imported-game and favorite filters compose
  in place. Opening a cartridge and pressing Back returns directly to the library.
- System cards show the corresponding handheld silhouette. The **LOGO LABELS**
  checkbox prints RetroRecomped onto the cartridge label while retaining its
  shell, shape and game name. It applies to library, details and insertion,
  and persists independently of custom designs. Studio always previews the
  editable custom label; switching branding off restores it.
- Tools are grouped by saves, customization and library management. Settings
  opens a category hub, with **All settings** retaining the full original list.
- Game details put Play beside the cartridge, followed by save management.
- Cartridge Studio offers label text, shell/label colors, arbitrary RGB hex,
  three emblems and custom PNG/JPEG artwork. It saves one visual design per
  registered game in application options; it does not modify ROMs or saves.
  The saved design is also used by the launch animation.
- Artwork is decoded to PNG, limited to 8 MB input and 2048 x 2048 pixels.
  Stored paths are confined to `launcher/cart_art/`. A failed preference write
  leaves the previous saved design intact.
- The 17.4-second startup has converging lightning, a synthesized guitar
  arrangement of the complete IntroBattle lead phrase, and a logo that docks
  into the header. Audio follows Music Volume and stops immediately on skip.
  The entire sequence can be skipped or disabled in Launcher settings.
- Play arcs the cartridge into the matching GB/GBC/GBA/DS silhouette and
  aligns before its final straight descent. At 1.65s it latches; at 1.98s the
  power LED and synthesized hardware-specific cue come on. At 3s lightning
  forms the logo inside the display; at 3.95s the camera begins flying into it,
  reaching fullscreen before the original boot callback at 5.6s. A bottom
  badge shows native framebuffer size and current window dimensions (DS: two
  256 x 192 displays). Application startup contains no cartridge animation.
  Backdrop music pauses during sequences. Enter/tap skips;
  Escape/B cancels. Duplicate input cannot boot twice.

## Verification

Passing checks: 78 new pure Lua assertions, 58 existing scroll/touch/delete
assertions, and 26 live UI checks on each of LÖVE 11.5 and 12. The pure Lua
checks cover sequence lifecycle, category filtering, grid sizing,
design validation and hardware selection. The preview host exercises the real
RomImporter and normal mouse/key dispatch with a harmless boot callback, including
the logo checkbox, composable filters, settings navigation, RGB input, PNG
decode, design save/reload and cancellation. See `tools/launcher_library_preview`.

The PNGs are actual LÖVE renders, including 480-pixel portrait and short-window
cases. Sample readiness and the KRIS summary are fixtures, not a real playthrough.
`intro-preview.mp4` and `launch-preview.mp4` pair deterministic rendered frames
with the guitar/latch/power sounds. The latch and power cues follow Sound Volume.

The audio is synthesized locally; no recorded audio or soundfonts are bundled.
The complete lead phrase was checked against the local reference's
`audio/music/introbattle.asm` and its use in `engine/movie/intro.asm`.
`tools/build_launcher_riff.py` regenerates the guitar WAV with NumPy;
`tools/build_launcher_latch.py` regenerates the mechanical click with Python.
`tools/build_launcher_power.py` regenerates the four original synthesized
device cues; these are recreations, not extracted firmware recordings.

Gameplay itself is not driven by the layout smoke host. Existing import, save,
mod and boot implementations remain responsible for those operations.

## Seasonal intro and settings follow-up

The current source removes the large enclosing ring from startup and insertion.
Startup includes original vector mascots with distinct entrances, effects and
logo delivery: autumn shade, hopping winter courier with a mail sack, shaking
spring branchling, and summer spark drake. Automatic follows local calendar
months; each season and plain Lightning can be selected manually. Application
settings expose the selector, label branding, and **Preview startup intro**.
This is installed in the production RomImporter, not only in the preview host.

Classic launcher selection and its explanatory row are removed; old preferences
migrate once to the RetroRecomped library. Application and game window titles
use RetroRecomped instead of the inherited Gen 1 project title. The appearance
category and labels use the fork's name; game-family controls include the
supported DS engine, with GB-only color controls filtered from GBA/DS views.
The save identity and compatibility formats retain their established names.

CPU checks pass: 58 sequence, 20 cartridge, and 51 seasonal/settings assertions,
plus syntax checks for the twelve changed application/preview Lua sources.
They exercise calendar boundaries, wordmark landing at three viewport shapes,
old-preference migration, settings rows, intro preview action, and global scope.

**Historical visual verification boundary:** existing PNGs/videos and the 11.5/12 native
smoke results above cover commit `b522ab45`, before this seasonal/settings
follow-up. They still show the former circular backdrop. Graphics review was
paused at that checkpoint for the user's OASC and VASC/KASC Android work.

## Playback, sharpness and cue synchronization follow-up

A later user-prioritized LÖVE 11.5 demo exposed an unsupported `chord` arc mode;
the shade now uses the supported `closed` mode. The repaired app stayed running,
and a native Retina screenshot confirmed the library's smoother cartridge
edges, filtered wordmarks and crisp type. Cartridge vectors use 3x supersampled
canvases with a 24-entry bound. Native display density is enabled on desktop;
the resolution badge reports physical output pixels. Game texture filtering is
not changed by the local cartridge renderer.

Startup waits for a drawn, visible, focused window and discards the background
wait delta. The activation click cannot accidentally skip it. Both application
startup and preview/replay entry points use this guard.

The current choreography reads `assets/launcher/intro_score.json`, also read by
the audio generator. Riff duration is now 17.4s, with the full lead phrase plus
heavy closing attacks at 13.68, 15.12 and 16.02s. Increasing, braided lightning
forms the wordmark; the shade fades in, makes a full orbit with correct front /
back layering, grips at the first attack, then carries and places it on the
last attack. Header art stays hidden until placement to avoid a duplicate logo.
When available, the audible Source playback position drives the animation.
Settings now has **Play startup intro** directly above its category cards, in
addition to the replay action next to the season selector.

CPU checks pass: 65 sequence, 20 cartridge and 59 seasonal/settings assertions.
New checks cover background startup, the activation click, audio-clock timing
and skip, orbit depth, ordered closing cues, and valid drawing modes across all
four seasonal render paths. The WAV's duration is checked against the cue sheet.
The latest cue choreography and overview button still await a native visual /
interaction pass: the user closed the demo and resumed prioritized Android
measurements. No new graphics run or video rendering has been started since.
