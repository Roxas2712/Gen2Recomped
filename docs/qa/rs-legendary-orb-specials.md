# Ruby/Sapphire legendary Orb specials

Ordinary Sapphire play reached Kyogre and continued its story, but logged
three unimplemented RS-only specials. The existing Emerald screen effect
was never called. Bind RS native specials 281/282 to the growing Orb and
fade, and 332 to the native map-music fade with script continuation.

RS keeps both uncentred red and blue at `(104,80)`; Emerald's uncentred
blue remains `(136,80)`. The centred variants remain `(120,80)`. Reuse the
existing circle, blend, camera and waitstate implementation. Do not change
Emerald's dispatch or claim the same extended special IDs in FRLG.

The original music callback requests `FadeOutMapMusic(4)` and waits until
the map music has stopped. The growing window and fading blend each own a
separate script wait; the camera must be centred after the fade.
Use the native BGM command service: the legacy sixteen-step helper's
shared-playback clock is not serviced for a native GBA stream and can leave
this special waiting forever.

Primary references at pokeruby revision
`5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f`:
[field_screen_effect.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/field_screen_effect.c),
[overworld.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/overworld.c),
[specials.inc](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/data/specials.inc).

CPU checks cover dispatch, all four colour/centre variants, waitstate
release, existing frame cadence, music completion and save isolation.
The music regression runs the actual script VM and native sequencer with
owned tracks and queueable hardware, plus shared music overrides, in both
editions. It verifies song ownership until tick 63, stopping at tick 64,
empty native output queues and script continuation.
The native driver uses a prepared field and the real VM special/waitstate
rows, map music, and final-renderer captures of growth, full tint/shake,
fade and restoration. These fixtures do not replace ordinary scene or
full-story acceptance. No ROM bytes, saves or generated art are included.
