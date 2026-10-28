# FireRed/LeafGreen Hall music and player data

The FR/LG ceremony bypassed the existing cartridge music-role resolver and
requested the old Game Boy label `Music_HallOfFame`. Native imports contain
their own `SONG_*` definitions, so that request could silently retain the
previous song. The ceremony now resolves `hallOfFame` through `Music.special`,
including conversion overrides and its existing old-cache fallback.

Player time uses the canonical read-only `SaveData.playSeconds` reader,
supporting the established scalar and hours/minutes/seconds table shapes.
The previous `playSeconds` fallback remains supported. Pokémon gender uses
the authoritative explicit/PID/species reader, and species sprite hooks
receive the documented `hof` context. Persistent names, identities, party,
induction/save ownership, timing and credits callbacks are unchanged.

Fifty assertions cover both editions, custom scene music, old-role fallback,
all supported clock shapes, explicit/native genders, custom nicknames,
sprite context and save immutability. The native fixture covers six-member
boy and three-member girl parties, actual Hall music/audio, confetti, each
member, the player clock, derived gender and real credits handoff. This is
prepared ceremony acceptance, not an ordinary story completion or a complete
FR/LG ending/save acceptance claim.
