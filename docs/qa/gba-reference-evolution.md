# Shared Gen1Recomp evolution presentation

All five admitted GBA editions select the pinned reference evolution scene
and its private message printer. Their scale cycles, B-cancellation cutoff,
point of no return, cries, evolution themes, fanfare and dialogue follow the
same reference controller. The reference draws procedural rays/particles;
this integration claims reference parity, not independently verified
cartridge pixel/timing accuracy for those effects.

Each edition retains its own existing normal/battle font, building background,
message panel, music enums and Pokemon pictures. Saved options and frame
selection stay authoritative. This needs no additional extracted artwork or
forced cache invalidation. The two added byte-exact sources join the hashed
reference inventory (210 files).

The controller receives temporary numeric species views. At its point of no
return, it calls the existing host evolution transaction exactly once. That
transaction keeps stable IDs, stats, damage, nickname, identity, dex, held-item
consumption and Nincada ownership. Native completion pops its own screen before
the host's actual evolution-move learning; the caller returns only after that
learning finishes. Cancellation does not mutate the party. Stone/trade
evolutions cannot be cancelled. Late completion calls cannot repeat the
mutation or callback. Other generations and custom data without these native
resources retain their existing view.

Reference modules, message state, particles and random generator are private.
Emerald uses the host's existing front-picture frames and procedural motions,
without ticking a battler. Draws may not change the save or host RNG.

`tests/gba_native_evolution_driver.lua` prepares level, cancellation, stone and
held-trade cases. It checks actual input, mutation at reveal, unchanged party
on cancellation, literal nickname characters, preserved damage, held-item
consumption, normal Gyarados BITE learning, callback ownership and real renderer
captures. These are prepared scene checks, separate from ordinary story runs.
