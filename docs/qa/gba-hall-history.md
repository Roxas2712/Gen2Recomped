# Persistent GBA Hall of Fame teams

The native ceremony already builds the cartridge's compact team, but that
record lived only inside the private presentation session. The host saved
the induction count and discarded the team when the cinematic closed.

The three native ending bridges now copy that completed record into
`save.gen3HallOfFameTeams` immediately before their existing save writer.
Up to fifty teams retain stable host species IDs, nickname, level, egg state,
trainer ID, secret ID and personality. `save.hallOfFame` stays numeric.
An owner records once across returned/raised write failures and retries.
The existing atomic save writer remains responsible for disk persistence.

Legacy count-only saves stay valid; historical teams cannot be reconstructed
from a player's current party. Snapshots and native PC views never modify
the live party. The new roster field participates in normal host species-ID
normalization on load. PC playback integration and native SAVE/CONTINUE
acceptance are separate outstanding checks; this change alone does not
claim a completed PC viewer.

`tests/engine/gba_hall_history.lua` checks all five native writer bridges,
snapshot ownership, egg identity, retention ordering, old saves and retry
idempotence. No ROM-derived data or private saves are distributed.
