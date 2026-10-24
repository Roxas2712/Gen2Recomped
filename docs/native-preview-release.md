# Native engine preview for Windows and macOS

This preview carries the combined native Gen3 contracts, audited palette
imports, static/animated palette caches and macOS OpenGL/Metal output fixes
from the development branch. It runs the native flat-world renderer. The
Origami port and First/Third Person integration remain paused.

Download the Windows or macOS **Gen2Recomped-NativePreview** ZIP from the
repository's pre-release, extract into a new folder and start its launcher:

- Windows: `OpenGL-Test.cmd` or `Gen2Recomped-NativePreview.exe`.
- macOS: `Metal-Test.command` or the preview app for Metal;
  `OpenGL-Test.command` for the OpenGL comparison. This is an ad-hoc signed
  test app, without Apple notarization.

Both packages contain the same engine payload and the same official LÖVE 12
source revision, `937eb3b21f973607ab080aa26b7ef2a6b3b2b663`. No separate LÖVE
installation is needed. The `.love` asset is for the same LÖVE 12 runtime;
using a stable LÖVE 11.5 installation is not this preview configuration.

Import your own supported Emerald/FireRed ROM through the launcher. ROMs,
extracted graphics and save files are not supplied. The preview starts in its
own `Gen2Recomp-NativePreview-<release-id>` profile. It does not migrate Gen1
or normal Gen2 saves or install automatic updates. Mods can now be installed
and enabled through the existing launcher in this dedicated profile; none
are bundled. The engine reports version **0.7.6 / mod API 2**, and mod manifest
requirements still apply. Enabling the loader alone does not establish VASC2
compatibility. The [real VASC release check](vasc-release-compatibility.md)
reproduces both its Gen3 exclusion and the engine version mismatch in Emerald
and FireRed. Keep
the default preview data location; portable/external-data roots are rejected.
Normal source builds do not activate the preview profile.

For feedback, record the source commit in `build.json`, game, OS, graphics
backend, window size, map/position, movement versus standing, and whether a
pause appears during a map change or in steady play. A screenshot of the
scene and approximate duration help separate loading from repeated stalls.
Never attach ROM files or extracted game caches.

The release notes and SHA256 sums identify the actual packaged payload and
runtime. `tools/build_native_preview.py` exports committed runtime sources,
excludes mods, applies the isolated entry points only in staging, and verifies
the archive excludes ROM/save/generated data. Windows wraps the official x64
runtime; macOS preserves the original framework links and signs a separate
preview bundle. Neither build installs to an existing application directory.

Local macOS GPU results are not Windows hardware acceptance. Omegadias's
Windows and macOS play tests are the next external acceptance step. OpenGL's
synchronous GPU readback still permits driver/compositor wait spikes; the
preview does not claim to eliminate those waits or establish all-gameplay,
fullscreen/context-loss or long-duration stability.
