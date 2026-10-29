# Emerald physical bag slots

Emerald's ordinary items can occupy multiple 99-item stacks. Flattening them
into one inventory count hid duplicate rows, miscounted full pockets and let
an action consume a different stack from the one selected.

The existing physical-slot adapter now admits edition-tagged Emerald bag
metadata with complete own-cartridge pocket capacities. Stable host IDs and
aggregate inventory remain authoritative; the optional serialized slot mirror
retains duplicate quantities and order. Merely reading old saves or asking
whether an item fits does not migrate or mutate them. Berries retain a single
999-item stack; sorted machine and berry pockets retain their native policy.
Battle Pyramid bags keep their existing separate path.

The bag list exposes each physical row. TOSS, medicine, held-item callbacks,
sales and PC deposits pass the selected slot. Sale proceeds and PC credits
follow a successful removal, so an outdated selection cannot pay or duplicate
goods. PC deposits also refuse an overflowing 999-item PC stack atomically.
Cartridge save import/export preserves supported Emerald and Ruby/Sapphire
partial stacks instead of writing an oversized aggregate into one slot;
FireRed/LeafGreen retain their existing single-stack representation.

Reference policy: Gen1Recomp
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b`,
`src/core/game3/profiles/emerald/bag.lua`. The policy adapter is independent;
the existing pinned common bag algorithm and its notices remain intact.

## Validation

- 134 focused checks pass: physical capacity, immutable preflight/cancel,
  selected removal, serialization, all-five cartridge save round trips,
  actual bag/party medicine dispatch, selected sales and PC deposits,
  full-PC refusal and an outdated sale selection.
- Existing tests pass 174 bag-toss, 115 physical inventory, 104 item-PC,
  152 mail, 1292 GBA field-item and 1350 object-sheet assertions.
- Native own-cartridge selected-stack acceptance is pending. The extended
  fixture covers 99/51 rows, cancellation, removing three from the second
  stack, real disk save/load of 99/48, medicine use from that stack, and final
  duplicate removal with a valid cursor.

This is scoped inventory work. Full Emerald story acceptance and native
SELECT reorder presentation remain separate open work. No ROMs, generated
resources, saves or private captures are included.
