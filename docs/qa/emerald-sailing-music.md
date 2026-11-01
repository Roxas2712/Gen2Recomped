# Emerald sailing music and native movement

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

Native qualification also exposed Emerald's stale faster-walk names: imported
movement rows retained the original action bytes `0x2D..0x30`, but some labeled
them as plain walking. The byte-based correction already used for Ruby/Sapphire
now admits Emerald too. Existing caches work without another ROM import.
The original Emerald action definitions and step tables specify four frames
per faster step, compared with sixteen for normal and eight for fast walking:
[original movement constants](https://github.com/pret/pokeemerald/blob/master/include/constants/event_object_movement.h),
[original movement implementation](https://github.com/pret/pokeemerald/blob/master/src/event_object_movement.c).

The independent 194-tile repeat-voyage oracle requires 1,068 movement frames.
The first-call path consists of two 97-tile halves requiring 500 and 568 frames.
The initial native candidate correctly rejected the stale cached movement pace;
that failed fixture is retained separately from accepted campaign progress.

The connected-edge escort allowance also covered only Ruby/Sapphire. Emerald's
boat leads the hidden player by one cell, so its edge step was refused before
the player's crossing could carry both actors. The same connected, paired-walk
allowance now includes Emerald; lone actors and unconnected edges stay refused.

The first Norman call revealed a separate ownership defect: its second half
uses `applymovementat`/`waitmovementat` for the original Route 104 boat after
reaching Route 105. Explicit movement now resolves that exact live carried
actor by its original map/id. An unloaded pooled object and a same-id actor on
the destination map cannot substitute for it. Ordinary local lookup remains
unchanged. The accepted normal campaign save remains independent of fixtures.

Sapphire's native regression also exposed stale arrival music: suppressing
ordinary playback at a held seam must still remember the destination's default
cue. `Music.rememberMap` now performs that existing bookkeeping without
starting or stopping playback; ordinary `playMap` uses the same bookkeeping.
This preserves sailing while allowing the original landing command to restore
Dewford rather than an older departure-map cue.

## Validation

- The real completed-step callback fails eight Emerald assertions before the
  music fix. With the paired-edge cases it passes all 441 checks; the
  uncorrected Emerald escort fails two of those assertions. The fixture also covers Ruby/Sapphire,
  FireRed/LeafGreen, Red/Crystal, incomplete steps, stale cues, release,
  duplicate prevention, surf/bike forwarding and complete-save immutability.
- The faster-walk callback regression rejects nine Emerald assertions before
  its correction and passes all 136 afterward. The neighboring actor-respawn
  and buried-movement suites pass another 95 and 110 checks.
- Explicit movement/wait ownership passes 70 checks across all five GBA
  editions; the old implementation fails 25. Cases cover the carried owner,
  same-id bystanders, missing/retired actors, waits and save immutability.
- Destination-map music ownership passes 50 checks across all five GBA
  editions. Remembering a seam changes no playing source; the original default
  command restores the destination cue. Public music ownership passes another
  168 checks, native source leases 145, and M4A fade timing 12.
- The 4,292 Gen2 connection-target and 94 Gen3 forced-movement checks pass.
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
- Native repeat-voyage timing, seams, landing, fade completion and dock exit
  passed before the first-call ownership correction. Both complete voyages and
  a Sapphire regression remain pending final native qualification.

No ROM assets, private saves or generated caches are included in this change.
