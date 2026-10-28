# Ruby/Sapphire ice puzzle continuation

A normal save on Sootopolis Gym's cracked ice changed its persistent step
counter on CONTINUE. The engine replayed the fresh-entry callback and discarded
the cracks. The same callback list also ran in header order, although the
cartridge executes TRANSITION, LOAD and RESUME in that order. Loading the old
stair counter before resetting it could leave a solved gate open on a new visit.

RS now distinguishes continuing a save from entering a map. It preserves local
field state on CONTINUE, runs LOAD and RESUME, and skips TRANSITION and warp-entry
tables. A fresh visit retains the native reset, before LOAD checks the stairs.
Other editions keep their existing callback dispatch.

`Gen3RsIce` records the original row masks in temporary variables, restores the
cracked metatiles through special 311, and applies the original delayed crack
and break sounds/tiles. The imported frame-table script still owns the falling
animation, sound and basement warp. Older fork saves migrate their witnessed
`gen3ThinIce` cells once; unrelated old temporary values are cleared before
interpreting the new row masks. Party, inventory, badge and battle state are
not supplied by that migration.

Primary references pinned to pokeruby
`5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f`:

- [Gym scripts](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/data/maps/SootopolisCity_Gym_1F/scripts.inc):
  counters 8, 28 and 69; stair updates; original fall script.
- [Field tasks](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/field_tasks.c):
  row masks, delayed cracking/breaking, sound IDs and restoration special.
- [Overworld](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/overworld.c)
  and [map loading](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/fieldmap.c):
  fresh transition versus saved-game LOAD/RESUME.

## Validation

`tests/engine/rs_ice_continue.lua` exercises native row masks, timing, sound
selection, legacy migration, actual VM registration/runner phases, ordinary map
setup and cancellation of stale per-map timing. It checks callback forwarding
for Emerald, FireRed and LeafGreen. The reversed-header-order test failed four
assertions before the RS ordering fix.

`tests/rs_ice_continue_native_driver.lua` uses imported Ruby/Sapphire maps and
ordinary directional input over the real renderer. It checks the first puzzle,
seven real cracking audio sources, reconstruction from saved bytes, fresh-entry
gate reset, the original basement fall and a clean puzzle restart. Captures also
check draw-time save/RNG immutability. This is a prepared fixture.

The separate ordinary Sapphire lineage solved all three puzzles, defeated
Wallace's five Pokémon, received the Rain Badge and TM03, and produced a normal
SAVE/YES checkpoint. Its runtime at that point was `f373f3559391d30e97dc09ba33b97dd43573a111`;
the subsequent callback-order refinement still requires its own native run.
This evidence establishes this arena segment, not a completed story or five
edition feature parity. ROMs, personal saves and private traces are excluded.
