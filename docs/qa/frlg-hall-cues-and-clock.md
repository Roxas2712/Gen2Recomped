# FireRed/LeafGreen Hall and credits music, player data

The FR/LG ceremony bypassed the existing cartridge music-role resolver and
requested the old Game Boy label `Music_HallOfFame`. Native imports contain
their own `SONG_*` definitions, so that request could silently retain the
previous song. The ceremony now resolves `hallOfFame` through `Music.special`,
including conversion overrides and its existing old-cache fallback. The
following credits had the same legacy-label problem and now resolve their
own credits role, including the established Hall fallback on raised errors.
The welcome transition also used an absent `audio.sfx.SE_APPLAUSE` alias.
It now plays FR/LG's native sequence 98 through the existing numeric sound
API. The functional ID is verified against the FR/LG song enum in reference
revision `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`; no audio is distributed.

Player time uses the canonical read-only `SaveData.playSeconds` reader,
supporting the established scalar and hours/minutes/seconds table shapes.
The previous `playSeconds` fallback remains supported. Pokémon gender uses
the authoritative explicit/PID/species reader, and species sprite hooks
receive the documented `hof` context. Persistent names, identities, party,
induction/save ownership, timing and credits callbacks are unchanged.

Focused assertions cover both editions, custom scene music, old-role fallback,
all supported clock shapes, explicit/native genders, custom nicknames,
sprite context and save immutability. The native fixture covers six-member
boy and three-member girl parties, actual Hall music/audio, confetti, each
member, the player clock, derived gender and real credits handoff. This is
prepared ceremony acceptance, not an ordinary story completion or a complete
FR/LG ending/save acceptance claim.

Validation on runtime `54ac31ec3cc2e418db44429053bb0c162d6bfd66`:
60 focused assertions and five related sound/session/readiness/menu suites
passed. Fresh full imports of both USA cartridges passed the actual-renderer
fixture, with 15 captures each and two real applause sources per edition.
Both genders and six-/three-member layouts reached their own credits song;
the save/RNG draw checks and frozen-source verification passed. Player-panel,
member and credits-handoff captures were visually inspected. The existing
reconstructed ceremony layout still needs the original-controller integration;
this change fixes music/data, not full visual or ordinary-story parity.
