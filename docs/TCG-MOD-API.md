# TCG mod API 1

Contributions by **Roxas2712**. This contract is for the optional `tcggbc`
cartridge backend. It does not impersonate the RPG engine's API 1/2/3 or load
RPG mods into the cartridge runtime.

## Package and activation

Create `tcg-mods/<id>/manifest.json` and `main.lua` in the LÖVE save directory
or a development source tree. IDs use lowercase letters, digits, `_` and `-`.
The TCG cartridge page lists these packages and toggles them in the separate
`tcg-mods/enabled.json`. Packages are disabled by default. The bundled
`tcg_status` package is a working overlay example. Toggle it on, then restart
the cartridge session. Existing RPG mod profiles are unaffected.

```json
{
  "id": "my_tcg_overlay",
  "name": "My TCG overlay",
  "version": "1.0.0",
  "game": "tcggbc",
  "api": 1,
  "online": "cosmetic",
  "capabilities": ["overlay", "memory.read"]
}
```

`online` must be `cosmetic` or `disabled`. `memory.write` requires `disabled`;
starting an online session with a writing or solo-only mod enabled fails with
an explanation. Both peers must have identical active package contents. The
fingerprint includes sorted package IDs, versions and every source/asset byte.
Assets are frozen at load time, so editing files during a session takes effect
only on the next start.

## Lua entry and lifecycle

The entry receives the global `api` (`api.version == 1`, `api.game == 'tcggbc'`).
Register callbacks with `api.on(event, callback)`; its result unregisters that
callback. Events are:

| Event | When |
|---|---|
| `start` | Both batteries are loaded; before the first simulated frame |
| `frame` | Once per simulated frame, before execution; never once per UI tick |
| `draw` | Draw the overlay after the original framebuffer |
| `link` | Serial-transfer or infrared-transition counters changed |
| `stop` | Before native memory and mod resources are released |

Callbacks receive a fresh plain event table. `api.info()` returns another fresh
snapshot: `game`, `api`, `romSha1`, `frame`, `online`, `seat`, `serial`,
`infrared`. Host is seat 0; joiner is seat 1. `link` data has `serial`,
`infrared`, `frame` and `seat`. Counters describe port traffic; they are not
promises of a completed duel or card transaction.

```lua
api.on('draw', function()
  local info = api.info()
  api.draw.rectangle(0, 0, 160, 11, {0, 0, 0, .8})
  api.draw.text('TCG frame '..info.frame, 3, 1, {1, 1, 1, 1})
end)
```

Callbacks have a 100,000 Lua-instruction budget, at most 16 subscriptions per
event and 256 overlay commands per draw. A callback failure stops the session;
its mutated battery is not committed over the pre-session file. Install mods
from trusted authors: this restricted environment is an integration boundary,
not a hardened sandbox against hostile resource-exhaustion code.

## Original game data

`api.memory.read(region, offset, length, seat)` copies bytes into a Lua string.
Offset is zero-based within the named region; length defaults to 1 and is at
most 4096. Seat defaults to the local player; online reads are restricted to
that device. Reads do not access the bus or advance emulation.

| Region | Bytes | Writable in solo |
|---|---:|---|
| `rom` | 1,048,576 | No |
| `wram` | 32,768 | Yes |
| `eram` | 32,768 | Yes |
| `vram` | 16,384 | No |
| `io` | 129, including IE | No |
| `hram` | 127 | No |
| `oam` | 160 | No |

`api.memory.write(region, offset, bytes)` copies at most 4096 bytes into WRAM
or battery ERAM, during `start` or `frame`, with `memory.write` declared.
Online writes are also denied by the native two-device host. No raw pointer,
CPU mutation or executable ROM patch is exposed.

These are original cartridge layouts, not decoded RPG Pokémon structures.
WRAM begins with C000-CFFF then its banked D000 region; ERAM is bank-linear.
Use symbols/layouts for the exact verified USA/Australia revision, such as the
[pret/poketcg SRAM layout](https://github.com/pret/poketcg/blob/master/src/sram.asm).
Changing a collection byte alone may leave the game's backup/progress data
inconsistent. State-writing mods own the game's original invariants and should
use an isolated save while developing.

## Assets, overlays and available Lua

`api.assets.read('relative/path')` reads only frozen files in this package.
There are no `..`, absolute paths or cross-package reads. Maximums: 128 files,
1 MiB per file, 16 MiB per package and eight directory levels.

Drawing uses original 160×144 screen coordinates, clipped to the game view:

- `api.draw.text(text, x, y, rgba)` — at most 512 bytes; an 8-pixel host font.
- `api.draw.rectangle(x, y, width, height, rgba)` — filled rectangle.
- `api.draw.image('asset.png', x, y, scale)` — package image, nearest filtering;
  maximum decoded dimensions 1024×1024.

RGBA values are 0–1. Colors default to white. `api.log(string)` writes a
package-tagged message to the existing log. Overlay images and fonts are owned
by the session and released when it closes.

The environment provides basic assertions/type conversion/iteration plus
package-local copies of `math`, `string` and `table`. Host randomness,
`string.dump`, `require`, `io`, `os`, `love`, `ffi`, `debug`, native libraries
and code-loading functions are absent. Text Lua is required; precompiled
bytecode is rejected. Mod source never arrives over the network.
