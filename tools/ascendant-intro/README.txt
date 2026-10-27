Recompiled Ascendant · fork integration by Roxas2712

The shared Ascendant IntroScene / VoxelBall and authored assets retain the
provenance in SOURCE.txt / ASSET-SHA256.json. Logo, character atlases, chime,
Lugia flight, cry and wind are unchanged local inputs in
.local/pokemon-x/intro-assets. The fork adds code-drawn Recompiled lettering
using Anton under the bundled SIL OFL (Anton-OFL.txt).

The full opening music plays while the Poké Balls roll. The logo appears at
6.16 s, Lugia calls at 9.8 s and flies across from 10.2 s, sweeping away the
logo, Recompiled lettering and characters. The sequence ends at 13.1 s.
There is no OmegaDias wordmark, eye animation or continuation card afterward.

For each X/Y start the order is: normal cartridge launch animation, complete
Recompiled Ascendant intro, then embedded game. Direct edition starters run
this once. The existing launcher animation preference disables both, and
input can skip a running animation without leaking into the game.
