# Pokémon Pinball (Game Boy Color)

Integration contributions by **Roxas2712**. This is the original 1999 GBC
cartridge, separate from the existing Ruby & Sapphire GBA backend.

## Private preparation

Use the unmodified USA/Australia rumble cartridge, exactly 1 MiB, SHA-1
`9402014d14969432142abfde728c6f1a10ee4dac`:

```sh
python3 tools/pinball_gbc.py prepare --rom '/path/to/Pokemon Pinball.gbc'
python3 tools/pinball_gbc.py status
```

Requires Git, CMake, Ninja, a C/C++ compiler, zlib and Python 3. The build driver
currently supports POSIX hosts; macOS arm64 is the qualified host. It uses two
compiler jobs and the existing QA storage guards, retaining a 20-GiB reserve.
`--cmake`, `--ninja` and `--runtime` select existing local build dependencies.
An existing runtime must be pristine and at the pinned revision.

The original cartridge is verified before generation and again before native
execution. ROM-derived C, native binaries, cartridge paths and battery files
stay in ignored `.local/pinball-gbc`. No cartridge or generated game bytes are
included in the repository. Native installation and the ready manifest are
replaced atomically after a successful link.

The prepared cartridge appears under Game Boy Color in the existing library.
`ASCENDANT_PINBALL_GBC_START=1` starts it directly when opening the source app.
`ASCENDANT_PINBALL_GBC_ROOT` selects a prepared backend root.

## Controls and saves

Arrow keys / X / Z / Enter / Right Shift map to D-pad / A / B / Start / Select.
The original in-game control options remain available. A connected gamepad uses
its D-pad, A, B, Start and Back. F1 shows controls; Esc saves battery RAM and
returns to the library. Losing window focus pauses execution and audio.

GBC battery data is exactly 8192 bytes at
`.local/pinball-gbc/player/pinball-gbc.sav`, separate from GBA Pinball and every
RPG save. Invalid existing files are rejected without replacement; a session
checks for concurrent changes before replacing its battery file. The host does
not import, migrate or edit other games' saves. Quick states, full-table view,
multiplayer and printer/SGB UI are not provided by this initial GBC host.

## Execution and provenance

[mstan/gbrecompiled](https://github.com/mstan/gbrecompiled) is pinned at
`743f52e73ec5cc90478b3591632406ac7764b45c`, derived from arcanite24 and
GB-Recomp's runtime work. SM83 routines translate to C and compile into a native
library. Uncovered code uses the runtime's interpreter bridge, counted in the
qualification report. This is a hybrid recompiled backend, not an entirely
static, interpreter-free rewrite of the game in Lua.

LÖVE supplies the window, original 160×144 color framebuffer, 44.1-kHz stereo
audio, controls and battery-file lifetime. The runtime uses its explicit HLE
post-boot initialization; it requires no downloaded Nintendo firmware. Real
hardware timing/TAS equivalence is not claimed.

The private build corrects two no-SDL omissions in the pinned runtime and its
MBC5 rumble bank mask. Build-directory copies preserve the original checkout:
the SDL keybinding header is conditional, released global joypad defaults come
from the host, and MBC5 rumble bit 3 is excluded from RAM banking as specified
by [Pan Docs](https://gbdev.io/pandocs/MBC5.html). Controller vibration is a host
approximation of the motor state; physical rumble has not been qualified.

Third-party rights remain with their respective authors. This integration does
not grant permission to redistribute their runtime, a combined binary, or
cartridge-derived code/data. Private local builds are the scope of this recipe;
no public binary release has been added.

## Validation

```sh
python3 tools/qualify_pinball_gbc.py --library /private/libascendant_pinball_gbc.dylib \
  --rom '/path/to/Pokemon Pinball.gbc' --frames 7200 --field red
```

This isolated test opens no player saves. It drives title/field selection,
launch and flipper inputs, captures framebuffer PNGs, checks audible PCM,
reports interpreter counts and checks the size-guarded battery-memory
round-trip. Repeat with `--field blue` and a separate `--output` directory.
Screenshots still need visual review; successful translation and a short smoke
test alone do not establish all capture/evolution/bonus modes as complete.
