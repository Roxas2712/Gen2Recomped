# Native Crystal caught-data ownership

Crystal now exposes the Gen1Recomp source Mon caught-data signatures and
constants through the existing native SDK module. One native implementation
owns the four live fields and the physical two-byte format. No supplied mod,
ROM, reference install, profile or save is changed by this contribution.

The observed failure was that the native SRAM codec retained only `caughtData`,
while source consumers edit `caughtTime`, `caughtLevel`, `caughtLocation` and
`caughtByGender`. Those edits previously could not survive export. The native
friendship bonus and trade OT mark also read only the packed historical word.

The shared owner is now used by real wild/PC catches, contest catches before
the later results/gate transition, ordinary script gifts, NPC trades, Shuckie
and egg hatching. Hatch level is the cartridge sentinel one. Fixed-OT gifts
use the source unknown/girl codes; the public explicit boy code retains its
separate event-landmark rotation. Arrivals read the live overworld time owner
or the existing saved RTC, not an independent clock.

The Crystal SRAM layout imports canonical fields and exports their edits in
all shared party, box and daycare record paths. Gold/Silver and unreviewed hack
layouts retain their reserved word unchanged. Format selection belongs to the
codec layout, independently of the currently running game. Old native Lua
records containing only the packed word hydrate once at validation, preserving
Pokemon/stat/move identity. Already authored source fields remain untouched.

## Validation

Committed implementation `9d4eb7e3cc666c252274648e0495e4945debbb55`:

- `gen2_caught_data`: 393,300 checks, including all 65,536 physical pairs,
  source normalization, masks and gift rotation; no LOVE runtime.
- `gen2_caught_codec`: 7,922 checks across native party, boxes, both daycare
  parents and pending egg, live edits, checksums, legacy hydration and opaque
  reserved layouts. All 256 possible values of each physical record byte are
  exercised through the actual native record exporter.
- `gen2_caught_native`: 133 checks through the actual API2 source import and
  native capture/storage, contest transfer, GivePoke, NPC trade, Shuckie,
  hatch, friendship, OT-mark and Lua-save owners. Audio and menu input IO are
  replaced; the arrival constructors and state writes run normally. RTC
  fallback is exercised at morning/day/night without an attached overworld.
- Existing field, semantic checkpoint, friendship, party-full catch, decoration
  SRAM and Mom-account suites passed on the same production implementation.

The same three new fixtures on predecessor main
`490eef1a0b4bd3b4f8d6cbdc78c0701e7e615d97` fail with 24 missing-API assertions.
This is a ROM-free semantic and native-owner qualification. It does not prove
GUI/Windows/macOS package acceptance, full VASC compatibility, source constructor
parity, standalone battle simulation or completion of other missing Mon APIs.

Contributions by Roxas2712 — https://github.com/Roxas2712
Independently authored integration is offered under LICENSE-ROXAS2712.md;
existing upstream and Gen1/third-party rights and notices remain effective.
