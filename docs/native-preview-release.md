# RetroRecomped intermediate pre-releases

Download the **Gen2Recomped-NativePreview** package for your platform from the
fork's pre-release. Availability varies: the refreshed `20261025.1` release
contains the two desktop packages; mobile/console entries below describe the
required future publishing workflow.

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

All five packages contain an identical engine payload. Windows/macOS use official
LOVE 12 revision `937eb3b21f973607ab080aa26b7ef2a6b3b2b663` as their base;
iOS builds that revision with pinned Apple dependencies. Android uses vendored
11.5a and Switch the hash-verified 11.5-nx1 runtime. No separate installation is
needed. Check `build-manifest.json` for the exact Lua runtime: qualified desktop
builds record `qualifiedRuntime` and include receipts. Their standalone `.love`
requires that extended runtime; stock LOVE still has the 60-upvalue limit.
Mobile/console runtimes are qualified separately and do not inherit the desktop
runtime's increased capacity.

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
development. The existing `20261025.1` desktop assets were refreshed from
`0acb23b7` with the qualified experimental 120-upvalue runtime. The original
tag/source archives retain `0780731e`; the manifest and README identify the
actual binary source and link to it. The preview profile is unchanged. This
update does not establish full-game 3D or universal mod compatibility.

## Publishing

Run **RetroRecomped intermediate pre-release** on the selected `main` commit
with a fresh `YYYYMMDD.N` release identifier and the engine `X.Y.Z` version.
The workflow runs ROM-free launcher and packaging contracts, then calls the
native runtime qualification workflow at the same commit. Linux x64, Windows
x64, Intel Mac and ARM Mac must pass stock/extended closure, C API and engine
checks; desktop jobs also test the actual LOVE host, thread VM and FFI. The
component job checks receipts, source trees and hashes and combines both Mac
slices. Desktop packaging consumes those exact components, signs the Mac app,
and verifies identical engine payloads. Missing or mismatched components fail
the build instead of falling back to stock. Mac minimum OS is derived from the
actual library load commands. iOS builds on hosted macOS, Android/Switch on
Linux. All five platform packages must pass embedded-payload parity before
publication as a **pre-release**; a missing package prevents publication.
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

## VASC4Gen2 development test status

The refreshed `native-preview-20261025.1` desktop downloads include native
camera/movement, Apple Silicon tier corrections and the qualified extended
runtime. The unchanged supplied generated renderer now initializes in the
tested Mac ARM copies. A stock LOVE installation still cannot compile it.

The separate experimental host passes normal Mart/Center doors, native menus
and Cherrygrove/Route 29 connections in First and Third Person on OpenGL and
Metal: 213 assertions, 12 transitions and four fresh window proofs per backend.
Source-bound qualification, packaging and GPU evidence, with the precise QA
bootstrap scope, is recorded in
[the runtime receipt](qa/native-foundation/johto-native-runtime-upvalues.json).
Some black-and-white objects remain visible. Complete model/effect/battle/story,
long-session and Windows GPU checks remain open. These results support a
limited experimental Mac play test. Current packaged-source/runtime tests at
`0acb23b7` add 20 assertions and four window proofs per backend for explicitly
staged battles in both camera modes: native menu input, visible colored Pokemon
cards, damage and victory callbacks. They do not establish ordinary encounters,
party switching, capture, RUN or all-story playability. Black/white overworld
actors, some command clipping and outdoor performance spikes remain open.
