# Pinball reference and functional coverage

Contributions by Roxas2712.

The functional reference is [pret/pokepinballrs](https://github.com/pret/pokepinballrs)
at `33ad42e8f2afca891831f03179820b96a3fdef6a`. Its main state machine,
`main.c`, `m4a_1.s`, `titlescreen.c`, `options.c`, `pokedex.c`,
`save_and_restore_game.c`, and board-specific processes guide the integration.
The integration runs the player's verified cartridge code. It does not replace
its game modes with launcher approximations or bundle the decompilation's assets.

| Original functionality | Integration and qualification |
| --- | --- |
| Ruby and Sapphire tables, ball physics, flippers, scoring | Native cartridge execution. Both tables pass the new 240-frame game/audio cadence check; both cache modes match images and RAM under recorded inputs. |
| Catch, hatch, evolution, travel, shops and mode banners | Original cartridge routines remain active. Unsupported expanded layouts use the complete original viewport. This is not a claim that every event has been reached in the current test. |
| Kecleon, Dusclops, Groudon, Kyogre, Rayquaza and Spheal bonus fields | Cartridge functionality is preserved; original viewport is used. A full natural playthrough through every bonus field is still unqualified. |
| Pokédex, options, BGM sound test and high scores | Entered and exited through actual guest inputs with USA/English and Europe/German ROMs. Native menu pictures are rendered at 240×160. |
| Original button configurations | All ten GBA inputs are exposed on keyboard and controller. Shoulders are convenient flippers; triggers provide L/R, left-stick click provides Select, Back opens the host menu. |
| Original SRAM and exact quick state | SRAM is preserved and reopened; exact quick-state image/RAM replay and legacy states are tested separately. No original-save schema is replaced. |
| Host view, image filters, integer scale, fullscreen | Existing Pinball player controls remain available. Full-table rendering is still beta and covers standard tables. |
| Friend point duels | Separate existing client protocol, not an original cartridge link battle. This fix does not qualify a production server or native network session. |
| Physical e-Reader cards, Game Boy Player rumble, original Pokédex cable exchange | Not qualified by these tests. No card data, hardware accessory or functioning cable session is invented. |

The HALT fix is in `tools/pinball-rs-native/runtime-fixes.patch`. The private
builder applies it to the pinned GBARecomp checkout, recognizes an already
applied patch, refuses conflicting changes and incorporates the patch into the
backend fingerprint. Existing ROMs, SRAM and quick states are retained. Restart
an already running app before using a replaced native library.

Reproduce with a prepared private installation:

```sh
python3 tools/qualify_pinball_runtime_patch.py
python3 tools/qualify_pinball_cadence.py
python3 tools/qualify_pinball_menus.py
python3 tools/qualify_pinball_native.py --frames 1500 --label halt-fixed
```

The cadence check verifies game steps and PCM duration, independently of window
refresh rate. The menu check does not modify guest RAM to unlock anything.
Reference/cached rendering comparisons establish equivalence between those two
host paths, not a complete match to retail hardware or every game scene.
