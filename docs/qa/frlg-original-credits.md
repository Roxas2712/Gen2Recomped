# Original FireRed/LeafGreen credits

The ending selects the byte-exact reference `src/ui/game3/credits.lua`, with
its own cartridge's 66 commands, 43 staff rows, thirteen map pans, five sprite
parameters, four Pokemon window/pose scenes, copyright and THE END. Its native
Latin font is shared with the original Hall context. Native circle, ball,
player/rival/ground and closing images replace the reconstructed geometry.
The original extractor and controller join the individually hashed inventory
at reference `fb7b0366efcb85e703e9e6d5a8a24d01456a109b` (208 files).

Map pans and reset requests belong to a private ending view. It never moves
the live player, replaces the world or writes flags to the save. The exact
controller supplies its WIN0 scissor and world fade through a loader-local
graphics/renderer context; the host composes maps beneath that overlay. There
is no global graphics patch or second credit state machine. Temporary GPU
objects are released on exit; shared MapLoader renderers remain owned by it.
The final reset invokes the existing ending callback once, preserving the
automatic League save and actual title/CONTINUE protocol.

`frlg-native-credits-v1` rejects stale caches. The selected verified USA
cartridge supplies all resources; no ROM bytes or generated assets are
published. Readiness rejects missing files, incomplete scripts, missing map
scenes and incomplete player/Pokemon sheets. Other editions keep their own
controllers and cache policies.

The native League fixture now checks the complete original credits after
real Hall-room scripting and failed/refused/successful atomic writes. It
also checks all native maps, both player/rival sheets, four original cries,
unchanged live world/player, THE END, title and actual CONTINUE. This remains
a prepared ending fixture; full ordinary FR/LG stories are separate work.
