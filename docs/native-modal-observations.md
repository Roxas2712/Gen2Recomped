# Native battle modal observations

The source `bag_menu`, `pokedex`, `party_menu` and `stat_growth` queries report
actual native controllers in the current stack, including covered controllers.
They do not allocate another screen, advance input or close unrelated menus.
The queries distinguish an unopened constructed controller from an open one.

Native bag, ordinary/FRLG dex, party and stat-window constructors stamp their
actual edition/data/save/stack/mod-loader cohort. A class name alone cannot
admit an unbound screen. Replacement of any owner field rejects the old
observation, including replacement before the first query. Missing nested
classes must never fall back to matching the enclosing battle class.

The observation registry has weak state keys and weak owner slots. It must
not retain a removed state/world through the value-to-game-to-stack cycle on
LuaJIT. Non-GBA queries remain absent and the native Gen2 stat constructor
keeps its existing state and callbacks.

This unit supplies real visibility queries needed by unchanged map/terrarium
viewport selection. Full bag/dex source commands, wide battle surfaces,
complete scene visuals and frame rate still need their own acceptance.
