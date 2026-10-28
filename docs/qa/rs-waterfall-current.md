# Ruby/Sapphire waterfall movement

An ordinary Sapphire run reached Ever Grande with eight badges and a Kyogre
that had learned WATERFALL normally. Directional input alone could traverse
the fall: the imported southward forced-movement row was ignored while
surfing. The A-button HM route also skipped the field-move announcement,
although the party-menu route already presented it.

The current handler now uses the imported waterfall predicate and its
forced-movement direction, after the existing sea-current lookup. Ordinary
water ends the push and collision still stops it. The A-button confirmation
uses the existing field-move presentation before handing back to the climb.
Neither the terrain importer nor the HM's badge/party gate changes.

Source contract: [pokeruby field_player_avatar.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/field_player_avatar.c)
pairs `MetatileBehavior_IsWaterfall` with `ForcedMovement_RideCurrentSouth`.
[field_effect.c](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/field_effect.c)
starts `FLDEFF_FIELD_MOVE_SHOW_MON_INIT` before the northward ascent.

ROM-free regression coverage: 146 assertions across all five GBA editions
exercise the actual world handler, current direction, collision, landing,
HM presentation/callback order and generation isolation. The related slide
and import suites pass another 157 assertions. The original movement
regression failed 15 assertions before the correction.

`tests/rs_waterfall_native_driver.lua` prepares its own surfer and badges,
then uses directional and A-button input on the imported Ever Grande map.
It checks the downward push, HM question, Pokémon announcement, ascent,
full descent, unchanged field PP and final-renderer save/RNG immutability.
Native Ruby and Sapphire tests passed on `de124808609e7bf96ea566023aa5cdae24bb6e7e`,
with six final-renderer captures each. The Sapphire ordinary continuation
also used its normally taught Kyogre WATERFALL and reached the upper water
through the A-button question and Pokémon announcement. The prepared fixture
is not an ordinary playthrough; neither result is a complete game acceptance.
Cartridges, generated art/audio, captures and saves remain private.
