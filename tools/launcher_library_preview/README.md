# Launcher preview

From the repository root, with the normal launcher assets available:

```sh
python3 tools/launcher_library_preview/run.py --love /path/to/love
```

The preview uses the separate `Gen2Recomp-layout-preview` identity and disables
cross-installation save recovery. Its Play callback logs the chosen game rather
than loading a ROM. The actual launcher classes and event handlers are used.

Environment options:

| Variable | Meaning |
| --- | --- |
| `LIBRARY_PREVIEW_FIXTURE=1` | Synthetic Crystal, Gold and Emerald readiness, with a sample KRIS summary. |
| `LIBRARY_PREVIEW_ALL_READY=1` | With fixtures, allow every importable game to exercise all four hardware sequences. |
| `LIBRARY_PREVIEW_VERSION` | Cartridge to preview, default `crystal`. |
| `LIBRARY_PREVIEW_MODE` | `library`, `game`, `tools`, `designer`, `settings`, `appearance`, `mods`, `news`, `intro`, `insertion`, `list`. |
| `LIBRARY_PREVIEW_WIDTH`, `LIBRARY_PREVIEW_HEIGHT` | Window dimensions. |
| `LIBRARY_PREVIEW_LOGO_CARDS=1` | Print the RetroRecomped logo onto the cartridge labels. |
| `LIBRARY_PREVIEW_TIME` | Explicit sequence time for a static capture, in seconds. |
| `LIBRARY_PREVIEW_OUT=/absolute/file.png` | Capture a settled frame and exit. |
| `LIBRARY_PREVIEW_SMOKE=1` | Run live input, navigation, design persistence and artwork checks; exit on completion. |
| `LIBRARY_PREVIEW_AUDIO=1` | Enable audio for an interactive intro preview. |
| `LIBRARY_PREVIEW_FRAMES=/absolute/folder` | Capture deterministic sequence frames into an existing folder. |
| `LIBRARY_PREVIEW_FRAME_COUNT` | Sequence capture count, default 91, including both endpoints. |

Static captures and frame captures pause background work. Interactive mode
uses the normal UI; any deliberate imports/settings edits belong to the
preview identity. Close its window to quit. Escape retains its normal back,
cancel and text-editing behavior.

F5 replays the full startup intro with audio when enabled. After the Play
animation the preview returns to the launcher, allowing repeated launches.
Automated smoke checks use a third identity, `Gen2Recomp-layout-smoke`, so
their persistence checks do not alter interactive preview preferences.
