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
| Friend point duels | Existing friendships and authenticated device invitations, optional import preparation, native joint start and consistent results passed with two actual clients over local and public HTTPS, including public WebRTC/WSS opponent pictures. Physical-device networking remains unqualified. |
| Physical e-Reader cards, Game Boy Player rumble, original Pokédex cable exchange | Not qualified by these tests. No card data, hardware accessory or functioning cable session is invented. |

The HALT and OBJ-layer fixes are in `tools/pinball-rs-native/runtime-fixes.patch`. The private
builder applies it to the pinned GBARecomp checkout, recognizes an already
applied patch, can upgrade a HALT-only installation without partial mutation,
refuses conflicting changes and incorporates the patch into the
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

The module detail view now follows the normal library page: one shared header,
cartridge/design control, a primary Play button and ROM reimport in the hero,
then SRAM import/export and the available language profiles. Save imports accept
exactly 32768 bytes and retain the previous file under a unique backup name.
Exports use the app's exports folder. A solo game's last native picture becomes
its private local preview on return. Quick states are written per language;
loading retains compatibility with the previous `quick.state` path when no
language-specific state exists. No RPG save editor or unimplemented cloud-sync
button is presented as a Pinball feature.

The actual separate-profile GUI was exercised in German/HeartGold, including
module Play → native game → F5 → F8 → host menu → return to the module page.
The language-specific state and preview were created. Layout bounds and button
overlap are checked at 420, 780 and 1400 content pixels; this does not certify
physical mobile devices or every localized font.

The OBJ fix selects one winning sprite by OAM order before compositing it
against backgrounds. It prevents the monitor aperture from blending against
other sprites. At two independently captured native/reference frames, the
incorrect pixels above the monitor fell from 464/1287 to zero. A native raster
regression covers transparency masks, OAM/background priority and both normal
and expanded rendering. Both cartridges retain exact quick-state replay and
cached/reference image/RAM equivalence.

The online player displays its own actual board and the friend's transmitted
board side by side. A separate bounded image worker handles previews; the
client executes one native game. A macOS activity lease protects active audio
and video from App Nap, allows idle system sleep, and ends on solo pause,
completion or close. Native preparation/waiting is deliberately silent.
The native worker owns the queueable audio Source and prebuffers six native audio frames (about 100 ms) to cover short
interpreter/scheduler spikes. A paused host menu discards current duel audio
instead of replaying an old backlog when it closes. Guest timing and sample
duration remain unchanged.
Picture updates prefer the separately authorized WebRTC channel, then WSS
relay and authenticated HTTPS fallback. The public same-Mac two-client run
qualified direct/relay failover; cross-NAT physical devices remain pending. See `PINBALL-MODCOMPASS.md` for the wire limits and the
distinction between synthetic tests, local native HTTPS duels and deployment.
