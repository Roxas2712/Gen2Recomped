# Pokémon Trading Card Game (GBC)

Integration contributions by **Roxas2712**. This optional backend runs the
original USA/Australia cartridge inside the existing LÖVE launcher, under
**Game Boy Color → Pokémon Trading Card Game**.

## Prepare locally

The supported cartridge is exactly 1 MiB, SHA-1
`0f8670a583255cff3e5b7ca71b5d7454d928fc48`.

```sh
python3 tools/tcg_gbc.py prepare --rom '/path/to/Pokemon Trading Card Game.gbc'
python3 tools/tcg_gbc.py status
```

Requires Python 3, Git, CMake, Ninja, zlib and a C/C++ compiler. Existing pinned
runtime checkouts can be selected with `--runtime`; `--cmake` and `--ninja`
select the build tools. Two compile jobs are used. The normal disk reserve is
20 GiB; `--min-free-gib` is an explicit per-run override for an owner-authorized
build, with a minimum of 2 GiB. It does not change the shared storage policy.

The runtime is [mstan/gbrecompiled](https://github.com/mstan/gbrecompiled) at
`743f52e73ec5cc90478b3591632406ac7764b45c`. Generated SM83 C is compiled into a
native library. Uncovered code uses the runtime's interpreter fallback; this
is a hybrid recompiled backend, not an interpreter-free rewrite in Lua.
The host uses HLE boot initialization and needs no Nintendo firmware file.

The verified original ROM remains at its supplied path. Generated C, the native
library and the ready manifest stay in ignored `.local/tcg-gbc`; no cartridge,
generated guest code or battery file is committed. The native host rechecks the
exact cartridge hash before running it. The pinned no-SDL runtime gets a local
build-directory correction for its unconditional keybinding include; the source
checkout remains pristine. Third-party rights and licence obligations remain
with the original authors. This recipe does not authorize redistribution of
runtime or game-derived binaries.

Current build driver: POSIX desktop. macOS arm64 is the development target;
Windows/mobile/console packaging is not qualified by this integration.
`ASCENDANT_TCG_GBC_ROOT` selects another prepared source root.
`ASCENDANT_TCG_GBC_START=1` opens the prepared game directly.

## Play and save

D-pad: arrows. A/B: X/Z. Start: Enter. Select: right Shift.
A controller uses D-pad/A/B/Start/Back. F1 shows controls. Esc saves battery RAM
and returns to the library. Use the original in-game save option to record
adventure progress before leaving.

Battery data is 32768 bytes at `.local/tcg-gbc/player/tcg-gbc.sav`.
Other editions' saves are never used. A process lock prevents simultaneous
writers; malformed files are rejected, and the original bytes are checked
again before an atomic replacement. Online sessions create a separate
`.before-online-*.sav` backup. A detected synchronization failure preserves the
pre-session battery file. The peer's battery data is never written locally as
the player's save.

## TCG mods

The cartridge page lists and enables TCG API 1 mods independently of RPG mods.
See [the mod authoring contract](TCG-MOD-API.md). A disabled example overlay is
included. Game data writes are solo-only; online mods must declare cosmetic
support, and both players must have identical active mod source and assets.

## Online duels and cards

1. Both players prepare the same cartridge using the same source/runtime build.
2. Host selects **ONLINE HOSTEN**. The endpoint field chooses the TCP port
   (default 8766). The host must be reachable at that port, e.g. over a shared
   VPN or a router port forward.
3. The second player edits the endpoint to the host's `IP:port`, then selects
   **ONLINE BEITRETEN**. This direct connection needs no hosted service account.
4. Both games start from each player's own battery data. Enter the original
   **Link Duel** menus for a battle. Use **Gift Center → Send Card / Receive
   Card** for cards, switching sender/receiver for the reverse direction.
   Deck configurations and Card Pop! use the same infrared connection.

The original supports sending/receiving cards; there is no new atomic,
simultaneous swap screen. The source protocol is documented in
[pret/poketcg's link routines](https://github.com/pret/poketcg/tree/master/src/engine/link).

Both clients exchange an active-mod fingerprint and simulate the same pair of devices, with canonical host/join seat
ordering. Controller inputs travel over TCP; the original serial and infrared
signals are exchanged locally between the two contexts at instruction
boundaries. A six-frame input delay absorbs network latency; larger delays
stall simulation rather than dropping inputs. CPU/RAM/video state checksums
stop divergent sessions. Focus loss releases local buttons and keeps an online
session advancing; solo play pauses while unfocused.

At connection time, each participant sends a complete 32-KiB battery copy to the
other participant. The direct TCP transport has no encryption/authentication;
use a trusted peer and a private VPN for Internet play. There is no matchmaking,
ModCompass friend invitation or automatic reconnect in this backend.

## Qualification

```sh
python3 tools/qualify_tcg.py --love /path/to/love \
  --library /private/libascendant_tcg_gbc.dylib \
  --rom '/path/to/Pokemon Trading Card Game.gbc' --frames 1200
```

The runner uses isolated QA identities and never opens player saves. It checks
partial network writes/reads, real loopback TCP, sequence/build rejection,
desync/timeout/disconnect, launcher ownership, the native picture/audio path,
battery size guards and two independent paired simulations. Native reports
count interpreter fallbacks rather than hiding them. Screenshot review and
completed original-game duels/card transfers are separate acceptance checks;
transport tests alone are not a claim that those game flows are complete.

## Current development evidence

On macOS arm64 with LÖVE 12, native startup/picture/audio, the full launcher
return path and the enabled example overlay were visually inspected. Two
independent paired sessions matched for 1,200 startup frames. Actual TCP
lockstep matched two native clients for 600 frames. The public mod contract,
native memory write guards and nonmutating memory reads were checked.

A private `TCG_QA=ON` build adds bounded routine-call probes only to the host
translation unit; production builds force this option OFF. Against matching
pret/poketcg symbols from revision `ed8e0a796099043c8d8aaea4726fa13b64625dd2`,
whose built cartridge matches the supported SHA-1, the original Gift Center
sent three selected cards and changed both collections correctly. The original
link-duel setup exchanged both 60-card decks and reached both opening hands.
Both probes also matched independent paired simulations frame by frame.

`tools/qualify_tcg_link.py` reproduces these isolated routine probes.
`tools/qualify_tcg_ui.py --love /path/to/love` reproduces the launcher and
example-mod captures. No player save is opened by these tests. Original failed
probe/UI runs are retained privately alongside the passing evidence.

This evidence does not cover a complete adventure, a finished match across
two Internet connections, Card Pop!/deck-transfer acceptance or all host
platforms. The launcher labels the backend experimental.
