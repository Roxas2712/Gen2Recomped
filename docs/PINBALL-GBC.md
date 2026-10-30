# Pokémon Pinball (Game Boy Color)

Integration contributions by **Roxas2712**, in the public
`Roxas2712/Gen2Recomped` fork. This is the original GBC cartridge, with a
separate native backend from Ruby & Sapphire on GBA.

## Prepare your own cartridge

Use the unmodified USA/Australia rumble cartridge, exactly 1 MiB, SHA-1
`9402014d14969432142abfde728c6f1a10ee4dac`:

```sh
python3 tools/pinball_gbc.py prepare --rom '/path/to/Pokemon Pinball.gbc'
python3 tools/pinball_gbc.py status
```

Requires Git, CMake, Ninja, a C/C++ compiler, zlib and Python 3. The build driver
currently supports POSIX hosts; macOS arm64 is the qualified host. It uses two
compiler jobs and the repository's QA storage guards and default free-space
reserve. `--cmake`, `--ninja` and `--runtime` select existing dependencies.
An existing runtime must be pristine and at the pinned revision.

The cartridge is verified before generation and native execution. ROM-derived
C, native libraries, cartridge paths and battery files remain ignored under
`.local`. They are not part of the public contribution. The library and ready
manifest are installed with individual atomic replacements after linking.

The prepared cartridge appears under Game Boy Color in the library.
`ASCENDANT_PINBALL_GBC_START=1` starts it directly from the source app.
`ASCENDANT_PINBALL_GBC_ROOT` selects a prepared backend root. The supported
cartridge is English; the GBA language profiles remain separate.

## Shared player features

The existing Pinball player supplies solo play, two local independent score
games, direct ENet duels, private TCP relay rooms and the friend-service client.
Duels use a fresh game on the selected Red or Blue field, matching ROM/build
identities and initial RAM checkpoints, a countdown and a five-minute gameplay
window. Scores and final results are exchanged; this is not an emulated cable
mode or an authoritative ranked competition. Duels never open the solo saves.
The received opponent picture is shown alongside the player's own game, at up
to six updates per second. Each client selects its own original/full-table view.

The `pinballgbc` edition is distinct from `pinballrs` throughout presence and
invitations. The public repository contains the ModCompass client and service
contract, not the complete server. GBC synthetic contract tests and real native
localhost transports do not qualify deployment or live GBC friend invitations.
See [the service contract](PINBALL-MODCOMPASS.md); its earlier production
qualification concerns the GBA edition only.

| Control | Action |
| --- | --- |
| Arrows / X / Z / Enter / Backspace | D-pad / A / B / Start / Select |
| X or controller A | Launch; also the default right flipper |
| Left or controller left shoulder | Default left flipper |
| Mouse left / right / middle | Left flipper / right flipper / launch |
| Player 2: WASD / F / G / Tab / backtick | D-pad / A / B / Start / Select |
| Esc / controller Back | Host pause menu; Q there returns to the library |
| F5 / F8 | Save / load quick state, disabled during score duels |
| F6 / F7 | Full table / opponent pane |
| F9 / F10 / F11 | Image filter / integer scaling / fullscreen |

The original in-game control configuration still applies. The motor bit drives
short optional controller vibration pulses; unsupported pads ignore them.
Physical rumble has not been qualified. Pausing, focus loss and shutdown release
vibration. Original guest pause remains on Start.

Battery data is exactly 8192 bytes, stored at
`.local/pinball-gbc/player/solo-en-1.sav`. SRAM import/export uses that size,
retains the previous import as a backup and never opens RPG/GBA saves. The
native writer rejects invalid lengths and detects concurrent file changes.
Quick states and the last solo preview live beside the GBC battery file.
Display preferences are stored separately from GBA Pinball.

## Full-table presentation

F6 composes a 192×272 board plus a separate 13-pixel text strip. It renders the
current half from live graphics and the other half using cartridge graphics
routines in an isolated snapshot. It does not stitch together camera history,
advance the canonical game twice or alter physics. Only the current half owns
the live ball and timer. Both halves use their own loaded CGB palettes.

The same corrections as the GBA compositor apply: current software OAM stays
paired with current camera coordinates, one sprite wins before BG priority is
resolved, and the HUD is rendered independently. The GBC window switches its
tile-data bank in a STAT interrupt; the host reproduces that switch and draws
only the authored eight-pixel text row on opaque black padding. No copy of the
small viewport, Diglett or flipper fragments can enter this strip.

The full-table frame stays fixed during standard-field loading, camera changes
and ball loss. Temporary loading uses the last complete world surface; live
bonus-count/menu window tiles are overlaid separately at their native size.
There is no automatic zoom back into the original half-table viewport. Menus
and unsupported bonus fields retain their complete original picture inside a
fixed portrait frame rather than being enlarged. The shared GBA player uses
the same fixed-scale framing for original-view sequences in full-table mode.
F6 explicitly returns to the original fitted view. The feature remains beta:
every capture/evolution/bonus scene and hardware equivalence are unqualified.

## Execution and provenance

[mstan/gbrecompiled](https://github.com/mstan/gbrecompiled) is pinned at
`743f52e73ec5cc90478b3591632406ac7764b45c`, derived from arcanite24 and
GB-Recomp runtime work. SM83 routines translate to C and compile into a native
library. Uncovered code uses the runtime's interpreter bridge, counted in QA.
This is a hybrid recompiled backend. LÖVE supplies the common window, input,
44.1-kHz audio and worker lifecycle. Explicit CGB HLE initialization requires no
downloaded Nintendo firmware.

Private build copies correct no-SDL host omissions and MBC5 rumble banking:
bit 3 controls the motor and is excluded from the RAM bank number, as described
by [Pan Docs](https://gbdev.io/pandocs/MBC5.html). The external checkout remains
unchanged. Native calls are serialized across worker threads because the pinned
runtime also has process-wide helpers. macOS active playback requests the same
worker QoS as GBA; waiting and pause relinquish it.

Third-party rights remain with their authors. This integration grants no new
permission to redistribute their runtime, a combined binary, or game-derived
code/data. No public binary release is included.

## Reproduce validation

```sh
python3 tools/qualify_pinball_gbc.py --library /private/libascendant_pinball_gbc.dylib \
  --rom '/path/to/Pokemon Pinball.gbc' --frames 3600 --field red --full-table
python3 tools/qualify_pinball_friends.py --love /path/to/love --edition pinballgbc
python3 tools/qualify_pinball_gbc_network.py --love /path/to/love --mode enet
python3 tools/qualify_pinball_gbc_network.py --love /path/to/love --mode relay --field 1
python3 tools/qualify_pinball_frames.py --love /path/to/love --edition pinballgbc \
  --label gbc-full-table --seconds 30 --seats 2 --full-table
```

The native test checks audio, snapshots, exact RAM isolation against a second
original-view context, quick-state restoration and size-guarded battery RAM.
Repeat with `--field blue` and a separate output directory. The network test
runs two real native clients over localhost with synthetic relay identities;
it never contacts a production account. The optional native CMake target
`pinball_gbc_render_test` uses synthetic tiles only and checks sprite priority,
software OAM, the STAT tile-bank switch and every pixel of the isolated HUD.
Screenshots still require visual review; short automated runs do not establish
a complete natural playthrough or cross-NAT/device networking.
