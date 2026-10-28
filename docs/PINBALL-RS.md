# Pokémon Pinball: Ruby & Sapphire

Integration contributions by **Roxas2712**. This backend is separate from the
Gen 3 RPG engine. The launcher uses its existing GBA cartridge artwork and play
animation, then presents the game in the same LÖVE window.

## Private build

Supply your own unmodified USA cartridge dump (BPPE, revision 0):

```sh
python3 tools/pinball_rs.py prepare --rom '/path/to/USA.gba'
```

CMake, Ninja, Git and a C++20 compiler must be available. The builder uses two
compiler jobs and a lock scoped to this Pinball installation. Independent CPU
checks can run concurrently. All generated game code,
ROM paths, runtime libraries, BIOS data and player files stay under ignored local
storage. The build checks the ROM SHA-1
`9fec81ce2c5df589e0371a0bf2f92a5fe8db730b` before generating or executing code.
It never rewrites the original ROM. `status` reports the local installation.
`Start-Pinball-Ascendant.command` opens the prepared game. It accepts
`ASCENDANT_LOVE_BIN`, or a private `.local/pinball-rs/love-bin.txt` containing
the executable path, before checking the usual local LÖVE installations.

The optional `--eu-rom` verifies and records the multilingual European dump
(BPPP, SHA-1 `b8b7881eaa9856b5ada99078ad1053d31cb79827`). It builds a separately verified native EU companion for the original
French, German, Italian and Spanish choices. English keeps the USA base. The
launcher selects the companion and original language menu automatically; each
language has separate solo SRAM. This uses the EU executable for those
languages, rather than claiming to transplant its text into USA machine code.

## Native execution and provenance

The builder pins [GBARecomp](https://github.com/mstan/gbarecomp) at
`e353848ca8e82e7860469a235784a000102e7781`. ARM/Thumb cartridge routines compile
into the native library; missing coverage still uses the framework's interpreter
bridge and is counted explicitly. This is not a fully static, interpreter-free
port and is not the unpublished PC port shown in the reference video.

The default replacement BIOS is
[emibios 0.2.1](https://github.com/coolbho3k/emibios/releases/tag/0.2.1), SHA-256
`95e6c8a6c236ed8e2629bdb60bc75791434c4f08ca69ad2305e30ca3f3c29d1b`.
An explicit `--bios` may select a personal 16-KiB BIOS instead. BIOS identity is
recorded in the private manifest. Replacement-BIOS timing has not been qualified
as retail-BIOS/TAS equivalent.

GBARecomp retains its **PolyForm Noncommercial 1.0.0** licence and its
`THIRD_PARTY_ATTRIBUTION.md`, including the separately licensed runtime
components. emibios retains **LGPL-3.0** and its corresponding source is available
from its linked repository/release. Those terms are independent of this fork's
contribution notice. The repository does not contain or license their binaries,
cartridge contents, ROM-derived assets or generated guest functions. Preserve
the applicable licences and provide corresponding source when distributing a
combined build; this change does not create a combined release grant.

[pret/pokepinballrs](https://github.com/pret/pokepinballrs) supplies the reference
layout and named game structures used to validate the USA addresses. Its game
code and extracted assets are not copied into this integration.

## Playing and score duels

The prepared entry appears with the other GBA games. Solo SRAM is separate from
duel instances. F5/F8 save/load the solo quick state. F6 switches between the original view and the experimental full table.
F9 changes pixel/smooth/LCD/scanline filtering; F10 toggles integer scaling; F11 toggles fullscreen. Esc opens the
player menu. Original controls remain available, including the game's own
control configuration.

A local duel opens two independent guests side by side, using either two
controllers or the two keyboard layouts shown in the menu. Controllers retain
fixed seats when another controller disconnects. Mouse buttons can drive player
one's flippers. Each duel boots empty, nonpersistent SRAM, automatically selects
the agreed table, and compares the starting RAM fingerprints before counting
18000 GBA frames (about five minutes). A player who reaches game over earlier
stops at their final score. Quick states are disabled during duels.

Online peers run independent games and exchange scores, not ROM bytes or player
save files. Build/content/ROM identity, table, duration, seed policy and starting
checkpoint must match. A disconnect cancels the round without awarding a winner.
This is a friendly score challenge, not a server-authoritative ranked mode.

Two independent transports are provided:

- Direct ENet UDP, port 7777. LAN works by host address; Internet hosting needs
  an accessible/forwarded UDP port.
- An explicitly selected private TCP relay with six-character room codes. Run
  `python3 tools/pinball_relay.py` for localhost tests, or explicitly configure
  its binding/hosting for remote access. The launcher defaults to localhost,
  and does not silently contact the old public link relay. The shared runtime
  requires an active ModCompass account before TCP relay entry, including a
  private relay; the check runs asynchronously. No relay has been deployed
  by this change.

The launcher also includes Pinball actions in the existing ModCompass friends
and inbox workspace: invite, accept/decline/cancel and automatic joint native
preparation. It uses a dedicated Pinball mode and the existing authenticated
CloudNet transport. **This client has been tested against a synthetic service,
not qualified against the production ModCompass backend.** Server support is
required before friend invitations can work live. See the precise
[server contract and handoff](PINBALL-MODCOMPASS.md). The public fork's `main`
contains the client, not the complete ModCompass server application.

## Display pacing correction

The subsequent full-table row-cache optimization, native-overlay layout
stabilization and longer displayed qualification are described in
[Pinball performance investigation](PINBALL-PERFORMANCE.md). Those longer runs
also measure source-picture holds, which can be hidden by a 60-Hz window.
The short samples below document the earlier FIFO correction.

The first displayed test reproduced only 41.2 distinct native images per second
despite a 60-Hz window and a fast native worker. Clearing the frame mailbox
before native execution caused consumers to miss completed pictures. The worker
now atomically publishes completed frames into a FIFO capped at three; the
player starts consuming after two frames. Guest simulation still advances every
frame at the original 59.7275 Hz. There is no fast-forward or altered physics.
This adds approximately one frame of initial video buffering; queue length and
latency remain bounded. Input commands are sent only when buttons change,
audio is started only when stopped, and display settings are written only when
changed rather than on every flipper press.

Actual 40-second LÖVE 12 Metal launcher samples after that correction:

| View | Distinct game images/s | Display p99 | Worst display interval |
| --- | ---: | ---: | ---: |
| Solo original, first / repeated | 59.8 / 59.8 | 18.2 / 18.4 ms | 20.1 / 42.4 ms |
| Solo full table | 59.7 | 17.7 ms | 42.8 ms |
| Two players, full table | 58.1 | 18.4 ms | 43.1 ms |

The full-table runs and the repeated solo run each still had one interval over 25 ms. These measurements
show the large solo delivery defect is fixed; they do not establish that every
stutter is gone. Two-player full-table native cost reached 18.4 ms p95, above a
single GBA frame budget. Both optional presentations remain available.
Aggregate evidence: [display samples](qa/pinball-display-pacing.json).

To repeat the real application test with your own prepared installation:

```sh
python3 tools/qualify_pinball_frames.py --love /path/to/love --label solo
python3 tools/qualify_pinball_frames.py --love /path/to/love --label two --seats 2 --full-table
```

Run GPU timing samples separately and keep the window focused. The harness uses
isolated profiles/player files and managed ephemeral hosts; it never writes the
production solo saves. It measures distinct native frames, not merely window
refreshes, and fails below 95% of native cadence, p99 at or above 25 ms, a maximum
display or source-picture interval at or above 75 ms, or focus loss. The optional
`--pause-unfocused` policy pauses and excludes background time, which is recorded
separately. These thresholds are a regression check,
not a guarantee of imperceptible stutters.

## Qualification and outstanding work

The initial native test ran two guests for 1800 frames each, reached the actual
Ruby board, checked matching pictures for matching input, and verified that
closing one guest leaves the other running. This is startup coverage, not a
full-game accuracy or device qualification. The recorded headless double-guest
sample was approximately 8.8 ms mean / 14.7 ms p95 on the development machine;
those numbers do not describe an actual displayed FPS measurement.

The ROM-free duel suite checks handshakes, exact twelve-digit scores, validation,
results and cancellation. The relay suite uses real localhost TCP connections,
including full-room rejection and disconnects.

The real LÖVE worker also completed two-guest, 1800-frame score rounds over
localhost ENet: USA/Ruby (50500–0) and EU/German/Sapphire (500–0; final rerun
2400–0; after the FIFO correction 4000–0). Matching
starting fingerprints and the resulting win/loss were checked. Controller
seat retention and focus suppression were checked with simulated controllers;
two physical controllers and two separate Internet-connected devices remain
unverified.

Separate native long runs advanced 18000 gameplay frames on each board with
the full-table view enabled: Ruby reached 625800 points and German Sapphire
27400, including game over and a new start. These are automated input runs,
not complete coverage of every bonus board. Concurrent checks were allowed;
the timing samples therefore do not certify displayed FPS or absence of
stutters. The separate worker sample remained about 8.9 ms mean / 14.4 ms p95
for two guests, excluding the display compositor.

The macOS LÖVE 12 Metal window test opened the library cartridge and native
preview, started a local two-guest game, switched the full-table view and
LCD/scanline shaders, and opened the pause menu. It caught and fixed the
external detail-page routing error. A subsequent native comparison checked the
separate original BG0 HUD strip without copying camera fragments. Other
platforms and physical controller pairs still need their own qualification.

The default presentation is the authentic 240×160 scrolling viewport with
aspect-preserving scaling. The optional full-table beta composes the live board
from its decompressed tile buffers and authored world sprite positions, using a
separate host PPU. It does not advance game timing or stitch camera history.
Menus, bonus boards, pauses and overlays retain the original complete viewport.
Offscreen entity poses still need wider scene qualification; the original view
remains selectable. A read-only comparison checks unchanged guest RAM and exact
restoration of the original pixels. The native bridge remains experimental until
broader scene, display and real-controller/network-device qualification are
completed. RPG-specific map/save editors and RPG Lua gameplay mods are not
automatically compatible with this separate native backend.

## Packaged launcher and October 27 HUD correction

Pinball remains visible under GBA before native preparation. Its import picker
accepts the verified USA base and the optional European companion; generated
libraries, original ROM references and solo data live under the writable
`pinball-backend` profile directory. A packaged app extracts its reviewed
builder sources there. Cold Pinball preparation currently requires CMake, Ninja,
Git and a C++20 compiler on the device. The prepared local demo installation does
not need these tools to play. No ROM-derived native library is distributed in
the app.

The first HUD correction copied completed canonical scanlines. That preserved
raster timing but also copied scrolling table pixels between the score glyphs;
comparison with the whole original row was therefore an insufficient oracle.
The corrected presentation observes the actual scanout and isolates BG0 on an
opaque black backdrop, excluding every board layer, OBJ and window mask. It
publishes only complete authored HUD strips and retains the latest one across
blank BG0 passes. Score changes still publish when the next glyph pass arrives.
Launcher notices have their own header row and no longer cover the score strip.

Quick states retain the isolated RGB strip in a flagged host extension, alongside
the unchanged native snapshot. Existing unflagged states still load; their HUD
is reconstructed by subsequent native scanout. Invalid extension flags/lengths
are rejected before loading. No host graphics are added to guest RAM or timing.
The opt-in CMake target `pinball_hud_test` checks synthetic raster inputs without
a ROM; native qualification additionally checks opaque/nonblank strips, cached
versus reference pixels/RAM, legacy state loading and exact new-state replay.
See `qa/pinball-demo-integration-20261027.json` for measured scope.

Original X, Y and Pinball cartridge photographs join the existing authenticated
ModCompass batch and remembered opt-in. Custom designs remain protected.

## Current-frame world sprites and native playback timing

The full-table adapter now reads the software OAM buffer that owns the current
sprite-group IDs. The original callback uploads that buffer to hardware OAM only
after its VBlank wait; mixing current IDs with the older hardware slots assigned
unrelated or disabled sprites. Camera-culled props also require original ROM
attributes/tiles. The pinned runtime's `native_code_view` does not expose plain
8/16 MiB ROM assets, so those reads now use a bounds-checked view of the already
verified cartridge. Guest OAM, palettes and timing remain untouched.
The reference was [pret/pokepinballrs](https://github.com/pret/pokepinballrs),
commit `33ad42e8f2afca891831f03179820b96a3fdef6a`, particularly `util.c` and
`main.c`; no reference checkout or extracted assets are packaged.

Pinball uses the standard primary Play control before its secondary settings.
Main keyboard forwarding retains scan codes and repeat flags. Active native
playback holds a 60 Hz consumer lease even without focus and keeps its worker's
latency-sensitive scheduling class until pause/wait/finish. Queueable audio uses
four blocks of preroll with sixteen slots; startup, rate changes and starvation
recovery refill before playback resumes. Closing or pausing releases the lease.

A 20-second graphical German Ruby test after these changes recorded no audio
restart, a maximum native step of 20.70 ms and maximum display interval of
33.67 ms. Its strict smoothness test still failed the 25 ms display-p99 target
(p99 33.27 ms); this is an improvement over observed 283 ms native stalls, not a
certificate of perfect 60 FPS. See the scoped QA JSON for all measured results.
