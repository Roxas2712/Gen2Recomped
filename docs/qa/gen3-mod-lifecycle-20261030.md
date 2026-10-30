# Native GBA mod lifecycle boundaries

Contributions by Roxas2712. Follow-up to the 30 October contract audit A07,
based on PR #402. No ROM, installed mod, player profile or Gen1 checkout is
modified.

The native GBA daycare now routes its percentage score through
`breeding.compatibility`, uses that same score for its actual egg roll, and
announces `breeding.egg_created` after committing the egg. Nonfinite answers
fall back to the native pair calculation; percentages clamp to 0..100. The
native Emerald integer roll and the existing Gen2 byte contract remain intact.

Native GBA hatching announces `egg.hatched` at its existing text completion
boundary, with the original egg, actual party slot and resulting individual.
Roamer moves and successful encounter selection announce their native slot,
map and reason without adding an RNG draw. Capabilities advertise these actual
producers. Gen3 Pokérus and unqualified intro aliases remain unavailable.

The Unified callback boundary recognizes parent and egg records explicitly;
native callback records keep their existing identity and vocabulary.

`gen3_lifecycle_callbacks` loads a synthetic, unchanged API2 mod through the
public loader in both native and Unified formats, for Ruby, Sapphire, Emerald,
FireRed and LeafGreen. It executes actual daycare creation, hatch text
completion and roamer selection, and checks refused encounters and retired
roamers. Regression coverage includes `unified_mod_callbacks`,
`gen2_lifecycle_callbacks` and `gen3_champion_ribbon_eggs`.

These are ROM-free engine consumer tests, not a GPU/device or published-mod
playthrough qualification. Hosted checks run only in the public own fork.
