# Native engine preview for Windows and macOS

The existing `native-preview-20261024.1` release currently distributes source
`321019ae83d70314aab7ac86d91ef0bf9b52b320`, stamped **0.8.45 / mod API 3**.
Its latest asset update fixes background downloads and the VASC package-cache
metadata. It retains the earlier native graphics and palette fixes. The
Origami/Gen3 port remains paused; active development focuses on VASC for
native Gen2/Crystal in separate test profiles.

The newer native First/Third Person movement, Apple Silicon quality policy
and experimental higher-upvalue runtime are **not in those public assets**.
Their scoped development evidence is recorded in
[the Johto checkpoint](johto-native-compatibility.md). The experimental arm64
runtime lets the unchanged supplied renderer extension initialize, but this
does not establish complete gameplay, Windows GPU or universal packaging
acceptance. Source changes alone do not replace an installed Lua runtime.

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

Import your own supported ROM, including Crystal, through the launcher. ROMs,
extracted graphics and save files are not supplied. The preview starts in its
own `Gen2Recomp-NativePreview-<release-id>` profile. It does not migrate Gen1
or normal Gen2 saves or install automatic updates. Mods can now be installed
and enabled through the existing launcher in this dedicated profile; none
are bundled. Mod manifest requirements still apply. Enabling the loader alone
does not establish full VASC compatibility. The older
[Gen3 VASC release check](vasc-release-compatibility.md) describes a previous
release and its Emerald/FireRed exclusion; it is not a current VASC4Gen2
acceptance result. Keep
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
