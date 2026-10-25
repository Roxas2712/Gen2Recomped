# RetroRecomped intermediate pre-releases

Download the Windows or macOS **Gen2Recomped-NativePreview** ZIP from the
fork's pre-release, extract into a new folder and start its launcher:

- Windows: `OpenGL-Test.cmd` or `Gen2Recomped-NativePreview.exe`.
- macOS: the preview app or `Metal-Test.command`; `OpenGL-Test.command`
  selects OpenGL. The app is ad-hoc signed, without Apple notarization.

Both ZIPs contain an identical engine payload and the official LOVE 12
revision `937eb3b21f973607ab080aa26b7ef2a6b3b2b663`. No separate runtime
installation is needed. The `.love` download requires that LOVE 12 runtime.

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
The workflow runs ROM-free launcher contracts, builds on a hosted macOS runner,
checks runtime digests and payload parity, and publishes a **pre-release**.
It does not start a game or alter the stable latest release.

`tools/package_native_release.py` invokes the existing isolated builder for
both platforms and collects packages, `.love`, README, `build-manifest.json`
and `SHA256SUMS.txt`. The tag points to the exact source commit recorded in
the manifest. Existing tags/releases are not replaced. Each package stamps
the requested engine version; the working source's development version can
differ. Mod API remains 3.

For feedback, include source commit, game, OS, backend, window size and the
action which triggered the problem. Never attach ROMs, credentials or caches.

## VASC4Gen2 development test status

The `native-preview-20261025.1` intermediate pre-release includes the native
camera/movement and Apple Silicon tier changes. It still bundles the official
runtime with the 60-upvalue limit: the supplied generated renderer extension
cannot fully initialize there. A source PR alone cannot change that runtime.

The separate experimental arm64 host passes normal Mart/Center doors, native
menus and Cherrygrove/Route 29 connections in First and Third Person on OpenGL
and Metal: 213 assertions, 12 transitions and four fresh window proofs per
backend. This evidence is bound to the earlier tested source revisions in
[the runtime receipt](qa/native-foundation/johto-native-runtime-upvalues.json),
not a full gameplay acceptance of every later launcher/save change. Some
black-and-white objects remain visible. Complete model/effect/battle/story,
long-session, Windows GPU and final cross-architecture packaging checks remain
open. These results support a limited experimental Mac play test, not a claim
that the public preview is fully playable with VASC4Gen2.
