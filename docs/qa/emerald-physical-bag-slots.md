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

- 160 focused checks pass: physical capacity, immutable preflight/cancel,
  selected removal, serialization, all-five cartridge save round trips,
  actual bag/party medicine dispatch, selected sales and PC deposits,
  full-PC refusal, an outdated sale selection and FRLG 999-item sale/deposit
  callbacks without physical-slot metadata.
- Existing tests pass 174 bag-toss, 115 physical inventory, 104 item-PC,
  152 mail, 1292 GBA field-item and 1350 object-sheet assertions.
  The 31 RS bag and 82 all-five pocket/return assertions also pass.
- Emerald passes the own-cartridge native fixture on `6cf8b100`: 99/51 rows,
  cancellation, removing three from the second stack, real disk save/load of
  99/48, medicine use from that stack, and final duplicate removal with a
  valid cursor. Eleven original-resolution final-renderer captures were
  inspected; draw preserves save/RNG and normal elapsed play time is accounted.
  Frozen runtime source remains unchanged. This reuses a separately accepted
  complete own-cartridge import/title with matching import-source fingerprints.
- FireRed and LeafGreen each pass their seven-view native bag regression on
  the same production runtime, including cancel, result timing, last-item
  removal, the 999-berry boundary and actual disk save/load. The pull request
  records final public CI and subsequent acceptance after integrating public
  main, separately from this original `6cf8b100` native evidence.
  FireRed's seven original full RGBA frames exactly match its inspected prior
  views. LeafGreen's six changed inventory-order views were inspected at
  original resolution; its berry view exactly matches its inspected prior.

This is scoped inventory work. Full Emerald story acceptance and remaining
native bag presentation/control acceptance remain separate open work. No ROMs, generated
resources, saves or private captures are included.
