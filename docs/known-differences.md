# Known differences from the original game

Only genuine remaining divergences live here: behavior that is still
**missing, wrong, or approximated for convenience** and would need more
work for true parity. Faithfully-ported behavior is documented in
docs/behavior-porting-notes.md; deliberate additions beyond the original
are in docs/new-features.md.

## Reimplemented unused Prof. Oak and Rocket Chief battles

The original ROM defines trainer data for `PROF_OAK` and `CHIEF`
(`data/trainers/parties.asm`) but never attaches either to an NPC, so
both battles are unreachable in the real game. This project makes them
fightable after the Hall of Fame:

- Prof. Oak battles you in Pallet Town once `EVENT_BEAT_CHAMPION_RIVAL`
  is set, using `ProfOakData`'s three starter-matched teams (the team is
  picked by the type that counters your starter, mirroring the rival).
- The Celadon Game Corner Chief battles you in his house post-game.
  `ChiefData` is empty in the ROM, so `OPP_CHIEF` is given a
  reconstructed party.

This is an intentional divergence: neither battle can be triggered in the
original game.

## Reimplemented unused Silph Co. card-key doors

`engine/events/card_key.asm` and the unused `CardKeyTable1/2/3` coordinate
lists (`data/events/card_key_coords.asm`) describe locked doors for Silph
Co. floors 2F-11F, but no retail `.blk` map layout ever places the closed
door block at those coordinates, so the card key check is dead code in
the original game. This project stamps the closed door block (`$54`/`$5f`
on floors 2F-10F, `$20` on 11F) over each of the 20 door coordinates on
map load, and swaps it for the open block once that door's
`EVENT_SILPH_CO_n_UNLOCKED_DOORn` flag is set (using the key from a Team
Rocket grunt, as in the original's unused design).

This is an intentional divergence: the doors are not visible or
functional in the original game. The door layout lives in
`tools/rom_manifest.json` (`field.cardKeyDoors.closedDoors`), hand-ported
since no retail ROM data encodes it; `src/import/RomExtractor.lua` copies
it straight through on ROM import.

## Fork fixture fingerprint baseline (2026-10-24)

The initial fork commit retained fixture golden `7de3051a7b3c108e`, but its
actual no-mod runtime already produces `41e69caf4afa35ab`. The same mismatch
exists on main `13af468b97dc37015d14ad5c71d7f067c3ee810d`, before the native
renderer foundation. The initial import contains no older canonical input
for the stale hash, so its exact historical record delta cannot be recovered.

The current fixture's reviewed link surface includes three synthetic species,
four synthetic moves, fifteen type categories, five statuses and 198 native
move-effect records, including the intended Gen2/Gen3 additions registered by
`MoveEffects` (`RETURN_EFFECT`, `WISH_EFFECT`, `YAWN_EFFECT`, among others).
The effect catalog intentionally merges Hoenn's records before registration;
silently excluding those records to keep an old fixture hash would weaken
link compatibility checks.

Re-pin **only the ROM-free fixture** to the runtime's existing value and also
commit the entire canonical input as
`tests/goldens/fixture_fingerprint_surface.txt`. The gate checks both that
input and its digest, and explicitly mutation-tests Gen2 and Gen3 effect
revisions alongside the previous battle-data mutations. The deliberate
`tests/bless_fingerprints.lua` command maintains both artifacts.

This correction changes no game data, runtime hash algorithm or current link
handshake. No ROM, imported-data or screenshot golden is regenerated. Future
battle-content changes must review the pinned input delta as well as the hash.

## Native GBA Beat Up party damage

Beat Up now reads each healthy party member's level/species base Attack
and target species base Defense, with per-hit native critical/variation
rolls, live callback eligibility, Substitute continuation and last-strike
special counter memory. The effect revision intentionally changes the link
fingerprint; see [the contract and remaining acceptance](native-gba-beat-up.md).

## Native GBA Beat Up shared side parties

Beat Up now reads the entire side party in two-trainer and player/ally
battles, retaining live slot replacement and the active user's HP/status.
Replacement benches remain owned separately. The reviewed effect revision
changes the link fingerprint; see [contract coverage and remaining scope](native-gba-beat-up-side-parties.md).

## Native GBA critical context and hit metadata

Critical exclusions now preserve native draw order for first/tutorial battles
and Teachy TV, including scripted Beat Up. Shared critical context fields,
physical item/current-species stages, Lansat/Focus Energy behavior and GBA
hit kind/Substitute metadata are covered by cross-engine contracts. The
reviewed scripted effect revision changes the link fingerprint; see
[verification and remaining scope](native-gba-critical-context.md).

## Fork inbox integration fixture (2026-10-25)

Integrating the existing native battle-command PR stack changes only four
records in the ROM-free fixture's `move_effects` section: Beat Up revision 3,
Spit Up revision 1, and the implemented Follow Me / Helping Hand primary
records. No species, move, type, status or constant fixture input changes.
The reviewed full input and its section pin are updated together; the fixture
digest becomes `a000e3862d11a73a` (previously `41e69caf4afa35ab`).
The GBA runtime command/party revisions also participate in GBA handshakes;
peers must run the same integrated engine rather than bypassing compatibility.


## Native Red content qualification baseline (2026-10-27)

The imported Red gate retained `227fd737aba15763` from the initial fork
commit. That value does not match either the initial fork runtime
`feb559cbe66a9abce0475572aff392246b80b82a` (`b401a4c32c6604af`) or the
unchanged main runtime `c3b4c864de04976e512454efbdbb992c73dab15a`
(`60874c75419b3c41`) against the same freshly imported US/EU Red cartridge.
The original canonical input for the old golden is unavailable.

The private canonical-surface comparison finds identical species, moves,
type chart, statuses and constants between those two runtimes. Their
move-effect sections differ: 3,154 versus 8,272 serialized bytes, reflecting
the engine's expanded native effect registry. The current main surface has
SHA-256 `56990828f0583bd8f134faeb23ffc2edf2cb010a4a302cd7e235272a0fd96653`.

Re-pin the Red gate to main's existing digest, using the explicit fingerprint
blessing tool. This qualification repair changes no runtime data, serializer,
effect registry or current link handshake. The ROM-derived canonical input
stays private; only its hashes are recorded. A committed API 1 loader fixture
with synthetic one-pixel PNGs replaces the absent example-mod dependency.
It still tests real disk discovery, validation, content overrides and asset
reads through the SDK's IO-backed filesystem.
