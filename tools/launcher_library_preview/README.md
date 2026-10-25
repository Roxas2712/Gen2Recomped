# Launcher preview

From the repository root, with the normal launcher assets available:

```sh
python3 tools/launcher_library_preview/run.py --love /path/to/love
```

The preview uses the separate `oasc-retro-launcher-qa-layout` identity and disables
cross-installation save recovery. Its Play callback logs the chosen game rather
than loading a ROM. The actual launcher classes and event handlers are used.

Environment options:

| Variable | Meaning |
| --- | --- |
| `LIBRARY_PREVIEW_FIXTURE=1` | Synthetic Crystal, Gold and Emerald readiness, with a sample KRIS summary. |
| `LIBRARY_PREVIEW_ALL_READY=1` | With fixtures, allow every importable game to exercise all four hardware sequences. |
| `LIBRARY_PREVIEW_VERSION` | Cartridge to preview, default `crystal`. |
| `LIBRARY_PREVIEW_MODE` | `library`, `game`, `tools`, `designer`, `settings`, `appearance`, `mods`, `news`, `intro`, `insertion`, `list`. |
| `LIBRARY_PREVIEW_MODE=original` | Direct original-cartridge download / local-image import screen. |
| `LIBRARY_PREVIEW_CATALOGUE` | Local public index JSON for a static mod-card fixture, without live release checks. |
| `LIBRARY_PREVIEW_THUMBNAILS` | JSON map of catalogue IDs to local preview images for that fixture. |
| `LIBRARY_PREVIEW_QUERY` | Initial catalogue search phrase. |
| `LIBRARY_PREVIEW_DETAILS=1` | Open the first matching mod in the enlarged image/details panel. |
| `LIBRARY_PREVIEW_UPDATE=1` | Simulated update badge for the fixture's single installed mod; no claim about a real release. |
| `LIBRARY_PREVIEW_WIDTH`, `LIBRARY_PREVIEW_HEIGHT` | Window dimensions. |
| `LIBRARY_PREVIEW_LOGO_CARDS=1` | Print the RetroRecomped logo onto the cartridge labels. |
| `LIBRARY_PREVIEW_TIME` | Explicit sequence time for a static capture, in seconds. |
| `LIBRARY_PREVIEW_OUT=/absolute/file.png` | Capture a settled frame and exit. |
| `LIBRARY_PREVIEW_SMOKE=1` | Run live input, navigation, design persistence and artwork checks; exit on completion. |
| `LIBRARY_PREVIEW_AUDIO=1` | Enable audio for an interactive intro preview. |
| `LIBRARY_PREVIEW_SEASON` | `auto`, `lightning`, `spring`, `summer`, `autumn`, or `winter`. |
| `LIBRARY_PREVIEW_FRAMES=/absolute/folder` | Capture deterministic sequence frames into an existing folder. |
| `LIBRARY_PREVIEW_FRAME_COUNT` | Sequence capture count, default 91, including both endpoints. |

Static captures and frame captures pause background work. Interactive mode
uses the normal UI; any deliberate imports/settings edits belong to the
preview identity. Close its window to quit. Escape retains its normal back,
cancel and text-editing behavior.

F5 replays the full startup intro with audio when enabled. After the Play
animation the preview returns to the launcher, allowing repeated launches.
Automated smoke checks use a third identity, `oasc-retro-launcher-qa-smoke`, so
their persistence checks do not alter interactive preview preferences.

The application itself has the same intro and season selector under
Settings → RetroRecomped, with **Preview startup intro** for immediate replay.
The Settings overview also has a prominent **Play startup intro** button.
Interactive startup waits for a visible, focused window before its audio or
animation begins. With audio enabled, choreography follows the playback clock;
the shared cue sheet is `assets/launcher/intro_score.json` (17.4s duration).
The standalone host is only a separate-storage way of trying the real UI.

Packaged LOVE runtimes with an embedded `game.love` are cloned into the managed
QA directory and unfused there. Their source app is preserved. Static catalogue
fixtures include one simulated installed mod; downloaded publisher images stay
local and are never added to the engine assets.
