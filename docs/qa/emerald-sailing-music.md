# Emerald sailing music at route seams

Emerald's original Briney script sets special flag `0x4001` and starts
`MUS_SAILING`, then carries the player and boat across connected sea routes.
The deferred map-music callback admitted that flag only for Ruby/Sapphire.
Emerald consequently replaced the voyage cue with each route's ordinary music.

The actual ordinary campaign on source `1d1e9b7` exposed both cases: the first
Route 104 voyage changed `SONG_1AF` to `SONG_191` at Route 105 while the native
hold remained true; Dewford's Slateport voyage did the same at Route 107.
The completed campaign segment and its later level-27 normal SAVE are retained.
No campaign replay or story-state edits are needed for this correction.

The callback now honors the native hold for all three Hoenn editions. Its
pending-cue consumption, stale-map handling and explicit script-driven landing
fade remain unchanged. FireRed/LeafGreen and the other generations keep their
existing map-music handling.

## Validation

- The real completed-step callback fails eight Emerald assertions before the
  fix and passes all 340 after it. The fixture also covers Ruby/Sapphire,
  FireRed/LeafGreen, Red/Crystal, incomplete steps, stale cues, release,
  duplicate prevention, surf/bike forwarding and complete-save immutability.
- The 110 native M4A source-ownership/lifecycle checks pass.
- The older standalone `parity_seam_walk_anim.lua` requires locally generated
  Game Boy data unavailable in this ROM-free CPU environment. The existing
  ROM-free connection-target and forced-slide suites cover the neighboring
  movement contracts instead; their results are recorded with this change.
- `emerald_boat_native_driver.lua` prepares two isolated original-ROM voyages:
  the complete repeat-voyage path and the first Norman-call path split into
  its two original movement lists. It checks independent ROM-byte timing,
  sailing music through all four maps, native landing music/release, actor
  alignment, the actual phone dialogue and an ordinary dock exit. These are
  prepared fixtures and receive no continuous-story credit.
- Native candidate execution and final captures are pending qualification.

No ROM assets, private saves or generated caches are included in this change.
