# Native Emerald and FRLG bag toss

The generic quantity/confirmation flow used host windows and vocabulary.
The adapter reads each cartridge's own text IR and uses the pinned native
font/window modules for quantity, YES/NO and result views. Emerald retains
its description panel; FRLG uses its lower bag windows. Custom item names,
host inventory IDs, selected frames and normal bag rebuild callbacks remain
authoritative. Ruby/Sapphire retain their existing native physical-slot path.

Reference: Gen1Recomp `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`,
`src/ui/game3/bag_menu.lua` and `src/ui/game3/rse/bag_menu.lua`.
The original count remains visible until the result is acknowledged, then
the host removes the chosen quantity once and rebuilds the list.

The native fixture exposed an existing generic 99-item stack limit.
Edition-tagged bag metadata now selects the reference limits: Emerald
ordinary stacks 99 and berries 999; FRLG stacks 999. This does not implement
Emerald's remaining physical split-slot behavior for repeated ordinary stacks.

## Verification, 29 October 2026

- 174 focused assertions pass real inventory admission, overflow refusal,
  removal and serialization; edition-owned limits; own text/cache admission;
  quantity bounds; custom names; cancellation and single result commit.
- 31 Ruby/Sapphire bag contract and 82 all-five pocket/return assertions pass.
- Emerald, FireRed and LeafGreen each pass a fresh complete own-cartridge
  import/title and a seven-capture native bag fixture: quantity three, NO,
  YES, result, a single item, the rebuilt list after that final item is
  removed, and 999 berries using the last frame (Emerald 20; FRLG 10).
  Ordinary item actions, cancel/save immutability with the normal clock
  accounted, exact removal timing, cursor/list refresh and real disk
  save/load pass. Both A and B result acknowledgement paths are exercised.
- Runtime source is `46511b62`; the final native fixture on `e4f90042` changes
  only test coverage. Each verification confirms unchanged frozen source.
  Original-resolution frames were inspected. Original full RGBA comparisons
  prove the six follow-up Emerald/FireRed views equal their inspected prior
  views, and all seven final LeafGreen views equal the inspected FireRed
  counterparts. The games still qualify from their own cartridges and titles.

The first native fixture correctly refused to prepare 999 berries before the
inventory fix; that failed run is not an accepted UI cache. A fresh independent
import qualifies the corrected extraction. Own cartridge text, generated
resources, saves and captures remain private. This accepts the scoped bag flow,
not whole-game story completion or a performance measurement.
