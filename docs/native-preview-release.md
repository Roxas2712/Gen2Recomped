# RetroRecomped intermediate pre-releases

Download the **Gen2Recomped-NativePreview** package for your platform from the
fork's pre-release:

- Windows: `OpenGL-Test.cmd` or `Gen2Recomped-NativePreview.exe`.
- macOS: the preview app or `Metal-Test.command`; `OpenGL-Test.command`
  selects OpenGL. The app is ad-hoc signed, without Apple notarization.
- Android: install the APK. It uses a separate preview application identifier
  and the committed test signing key.
- iPhone/iPad: sign the unsigned IPA using a sideload tool or your Apple team,
  then install. An unsigned IPA cannot be directly installed on a stock device.
- Nintendo Switch: extract the ZIP at the SD root. Start the preview NRO under
  `switch/gen2recomp-native-preview/` with full application memory via hbmenu.
  The preview does not bundle the stable-channel OTA updater.

All five packages contain an identical engine payload. Windows/macOS bundle
official LOVE 12 revision `937eb3b21f973607ab080aa26b7ef2a6b3b2b663`; iOS builds
that source revision with pinned Apple dependencies. Android uses the vendored
11.5a runtime and Switch the hash-verified 11.5-nx1 runtime. No separate runtime
installation is needed. The `.love` download requires the supplied LOVE 12
runtime on desktop; the 11.5 allowance is limited to Android and NX ports.

Import your own supported ROMs and save files. ROMs, extracted game caches,
account credentials, save files and mod packages are not supplied. The preview
uses its own `Gen2Recomp-NativePreview-<release-id>` data profile. Existing
profiles are preserved and are not automatically migrated. Normal source
builds do not activate this preview isolation. Keep the default data location;
portable/external-data roots are rejected by the isolated preview.

The launcher provides native ModCompass registration, sign-in, developer
repository linking, mod browsing/downloads, cloud saves and Pokemon Bank.
Mod version and generation requirements still apply. Save-bound compatibility
review can restore known packages or continue from a separate slot copy.
Exact mid-battle execution snapshots and seamless device handoff remain in
development. The extended-upvalue LuaJIT candidate is not bundled: mods which
exceed the official runtime's limits can still fail to load. This pre-release
does not establish full-game 3D or universal mod compatibility.

## Publishing

Run **RetroRecomped intermediate pre-release** on the selected `main` commit
with a fresh `YYYYMMDD.N` release identifier and the engine `X.Y.Z` version.
The workflow runs ROM-free launcher and packaging contracts, builds desktop and
iOS on hosted macOS runners and Android/Switch on Linux, checks runtime digests
and actual embedded payload parity, and publishes a **pre-release**. Every one
of the five platform builds is required; a missing package prevents publication.
It does not start a game or alter the stable latest release.

`tools/package_native_release.py` invokes the isolated desktop builder.
`tools/package_native_port.py` embeds that frozen payload in the three port
packages, using `--game-love` for mobile. `tools/assemble_native_release.py`
validates all five builds before collecting packages, `.love`, README,
`build-manifest.json` and `SHA256SUMS.txt`. The tag points to the source commit recorded in
the manifest. Existing tags/releases are not replaced. Each package stamps
the requested engine version; the working source's development version can
differ. Mod API remains 3.

The build manifest records build verification, launch verification and physical
device evidence separately. Package contract tests use synthetic binaries and
do not count as device evidence. A successful build does not establish gameplay,
touch/controller behavior, suspend/resume, mod networking or extended-upvalue
support on a phone or console; those runtime acceptance items remain open.

For feedback, include source commit, game, OS, backend, window size and the
action which triggered the problem. Never attach ROMs, credentials or caches.
