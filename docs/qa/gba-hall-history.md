# Persistent GBA Hall of Fame teams

The native ceremony already builds the cartridge's compact team, but that
record lived only inside the private presentation session. The host saved
the induction count and discarded the team when the cinematic closed.

The three native ending bridges now copy that completed record into
`save.gen3HallOfFameTeams` immediately before their existing save writer.
Up to fifty teams retain stable host species IDs, nickname, level, egg state,
trainer ID, secret ID and personality. `save.hallOfFame` stays numeric.
An owner records once across returned/raised write failures and retries.
The existing atomic save writer remains responsible for disk persistence.

Legacy count-only saves stay valid; historical teams cannot be reconstructed
from a player's current party. Snapshots and native PC views never modify
the live party. The new roster field participates in normal host species-ID
normalization on load.

The PC special now opens the pinned `hall_of_fame_pc.lua` controller in a
private scene context and resumes the original script once on return.
The native controller selects saved members, plays their cries, moves back
through teams with A and exits with B or A at the oldest team. Missing legacy
records use the cartridge's original error page. It never induces a new team
or invokes the save writer. All five editions now have native fixture acceptance covering
history save/load, all four PC views, native input/return ownership, atomic
write failures/retries and actual post-credits CONTINUE with retained teams.
FireRed/LeafGreen use independent fresh import qualification and each passes
52 combined native options/PC/ending captures on integrated source 5081f60.
Representative original-resolution views include current and previous teams,
eggs, the legacy error page, the player panel, title and actual Pallet CONTINUE.
Sapphire additionally passes its independent fresh import and 25-view native
PC/ending matrix on source c5cc461. A targeted Emerald matrix on that same
source passes all 37 options/PC/ending captures after the public-main renderer
merge. Source-canvas and complete-window title ink agree in every measured
options state. These are functional and visual checks, not performance
measurements or complete ordinary playthroughs.
CPU input checks alone are not visual acceptance.

Ruby/Sapphire use their own PC presentation facts from
[pokeruby f6e2a590](https://github.com/pret/pokeruby/blob/f6e2a5901e83383ad666c7ff564cecfcbcb55081/src/hall_of_fame.c):
title at (0,0), information tiles (4,15), (9,15), (7,17), (13,17),
pink dimming and the native standard corruption window. Those games have no
Emerald/FRLG control-hint text. Their own ROM aliases supply the existing
Hall labels. The reference controller remains byte-exact; the RS draw adapter
is independent. Emerald/FRLG use the reference draw function and own labels.
All fonts, frames, Hall artwork, sprites and cries use existing native packs.
The provenance inventory contains 216 exact reference files.

`tests/engine/gba_hall_history.lua` checks all five native writer bridges,
snapshot ownership, egg identity, retention ordering, old saves and retry
idempotence. `tests/engine/gba_hall_pc.lua` checks native selection, metadata,
cry ownership and the real script callbacks in all five editions.
`tests/gba_hall_pc_native_driver.lua` prepares actual history/save/load and
renderer/input checks. The three existing native ending fixtures also require
one retained six-member roster after IO failures and unchanged actual CONTINUE.
No ROM-derived data or private saves are distributed.
