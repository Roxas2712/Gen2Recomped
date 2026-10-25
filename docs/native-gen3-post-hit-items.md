# Native GBA post-hit item command

This change is stacked on #244. It aligns the shared King's Rock / Shell Bell
move-end command with the pinned, unchanged Gen1 reference
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. Gen1 is read-only.

## Contract

The native damaging command retains its first damage, including its native
substitute convention, rather than summing every hit. The shared held read runs
after Choice Band and the ordinary move-end cure sweep. An empty hand still
produces the same read. Public hook substitutions remain authoritative.

King's Rock performs the reference's extra canonical player-slot read, including
when the attacker belongs to the other side. A changed first answer selects its
own parameter; otherwise the second read selects the chance. RNG runs before the
move flag and living-target checks, and secondary refusal checks preserve native
Shield Dust, substitute, Inner Focus and already-moved behavior. The player-slot
parameter rule intentionally matches the pinned reference; this is not a claim
that it reproduces every cartridge edition's intended behavior.

Shell Bell uses the first damage and current divisor, with minimum one HP and
maximum-HP clamping. Its native held-item animation identifies the holder in both
positions. Physical item identities 186, 187 and 219 retain intrinsic GBA effects
even if mutable descriptive metadata clears them; public hooks can replace them.

Spread scripts retain their chosen target order and count occupied defending
slots until queued removal, including a just-fainted defender. An attacker that
faints before a later ordinary spread body does not run its damage commands.
Non-GBA damage and item handling retain their existing paths.

Already-moved state belongs to the current logical turn. Spectator action pairs
are buffered FIFO until the current animation/command queue finishes, preventing
an early next-turn packet from changing the turn under a running command.
Native battle protocol revision is 13; party codec remains 1. The independent
unchanged-hasher token audit changes only revision 12 to 13, yielding
`beacb71804a6af34`; legacy digest `e33d251961f2a41d` is retained.

## Validation status

Development checkpoint, before the final complete regression gate:

- Shared command: 7,488 paired rows, retaining all held reads, public parameters,
  RNG, activation, first-damage consumption, HP, flinch and animation metadata.
- Initial actual-script matrix: 13,200 paired rows match for Tackle, Double Slap,
  Triple Kick, Surf and Sleep Talk. A subsequent matrix also includes Earthquake
  and must pass before publication.
- Actual host, guest and spectator: 172 checks pass across FireRed and Emerald,
  including physical items, a stateful second held read, already-moved targets,
  skipped PP, complete held/event/RNG traces and completed state hashes.
- The previously mismatched complete successful Sleep Talk probe now has the same
  ten ordered held reads in both engines; awake/empty/blocked cases retain 2/2/4.

Failed and superseded fixture observations are retained separately in local QA.
The first link probe omitted the owned move's flinch flag; after supplying the
native-shaped flag, it exposed the real spectator turn-overlap bug. No rows are
filtered to establish equality. Final baseline, full engine regression, wider
contract matrix and combined-fork acceptance are still pending at this checkpoint.

## Scope

The executable reference comparison covers registered FireRed and Emerald paths.
Ruby/Sapphire's separate per-hit item scheduling is not certified. Other special
script boundaries, full catalogs and controllers, graphical playthroughs and
unchanged full-mod acceptance remain open. No ROM data, imported caches, normal
saves or third-party mod assets are committed.
