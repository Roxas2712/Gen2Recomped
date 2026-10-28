# Ruby/Sapphire arrow and slide floors

Ordinary Sapphire play reached Mossdeep Gym with no forced-floor rules:
the reader still inspected Emerald's code/table addresses. Arrow art was
present, but released input did not travel along the conveyor. The same
missing rules also remove the slide-floor barriers in Sootopolis Gym.

The per-edition stage overrides now identify the original dispatcher,
predicate/action tables and walk/slide drivers. The existing reader decodes
the loop bound, predicates, direction immediates and driver calls. No floor
rules are supplied as fallback data. RS import requires all eight floor rules
and changes its cache revision so an earlier incomplete import is rebuilt.

Resuming the ordinary gym traversal also exposed a direction handoff defect:
the southbound slide at `(3,13)` enters a slippery crossing at `(3,14)`.
The legacy ice handler reused an older slide direction or the locked sprite's
facing, reversing travel and creating an endless two-cell bounce. A directed
floor now hands its actual travel direction to the slippery continuation;
Gen3 keeps its facing lock. The native regression enters that conveyor from
the side and must reach the original exit `(14,26)` after releasing input.
Gen2's existing facing behavior remains unchanged.

| Original USA dump | Dispatcher | Predicates | Actions | Walk driver | Slide driver |
| --- | --- | --- | --- | --- | --- |
| Ruby | `058944` | `30FB58` | `30FBA0` | `0589EC` | `058B6C` |
| Sapphire | `058948` | `30FAE8` | `30FB30` | `0589F0` | `058B70` |

The dispatcher compares its index with 17 at offset `4E`. Its literal pool
names the predicate table. The adjacent action table has an initial NONE
entry followed by one action per predicate. The twelve direction wrappers
and waterfall decode through the existing reader; slip/mat/slope functions
remain under their separate handlers.

Primary source: [pokeruby field_player_avatar.c](https://github.com/pret/pokeruby/blob/master/src/field_player_avatar.c),
especially `sForcedMovementTestFuncs`, `sForcedMovementFuncs`,
`GetForcedMovementByMetatileBehavior` and the walk/slide wrappers.
The [original gym scripts](https://github.com/pret/pokeruby/blob/master/data/maps/MossdeepCity_Gym/scripts.inc)
set switch four's red arrow east or north through ordinary `setmetatile`.
They do not use Emerald's separate rotating-object command; its unsupported
RS extraction warning is not the cause of this gym failure.

Validation distinguishes synthetic malformed-code contracts, a prepared
real-map switch/conveyor fixture, and the separate ordinary-input story
lineage. None of those alone qualifies a complete game or all gym puzzles.
