# Native ApricornBalls and Kurt selection

The GSC importer reads the actual `ApricornBalls` pairs in cartridge order,
retaining native apricorn/ball item IDs and row indices. A single `$ff` ends
the table. Missing symbols leave no invented recipe data; explicit empty or
malformed/truncated tables never fall back to retail rows. Reads are bounded
and cannot cross a cartridge bank boundary. The map-script output includes
recipe records and completeness metadata. Stock Gold/Silver/Crystal cache
markers require reimport; other edition markers are unchanged.

Kurt's actual native special now consumes this imported order. The old fixed
item-ID order put several colours in the wrong positions. Historical stock
caches retain selection until reimport in native red/blue/yellow/green/white/
black/pink order, without fabricating their missing ball mappings.

Gold/Silver take one apricorn without opening a quantity menu. Crystal asks
for quantity, including a one-item stack; cancelling quantity returns to the
apricorn list with its cursor retained and consumes nothing. An explicit
CANCEL row and bounded scrolling retain access to the complete list. The
quantity is capped at99 and the native inventory is rechecked before removal,
so a changed bag cannot mint a paid job. Unreviewed hack layouts retain their
previous quantity-cancel protocol and are not given a guessed table import.

The native script variable still receives the actual selected item byte.
The existing `g2KurtApricorns` field holds its confirmed quantity. Native
script branches, event/working flags, daily resets and ball choice remain
script-owned. This does not add a competing Kurt job model or rewrite a ROM
script's ball operand merely because its selection table contains a pair.

Validation:198 synthetic checks use actual importer/map-script serialization,
Gen2ScriptVM, ScriptRunner, StateStack, Menu input and Bag operations. They
cover order/bounds, malformed data, cache readiness, Gold/Silver single-item
handover, Crystal confirmation/reselection/cancellation/scrolling and a real
`verbosegiveitemvar` collection path: a full ball stack preserves the event,
successful delivery grants the confirmed quantity and event clearing prevents
duplicate collection. Only text/audio IO is substituted. A private read-only
Crystal Rev0 table probe finds seven complete rows, agrees with an independent
byte decoder and leaves the original ROM unchanged. It is not a full import,
GPU, original-story or Gold/Silver actual-ROM acceptance claim.

The complete `apricorns` registry and legacy Apricorns facade, authored recipe
events/ball-output binding, complete native daily/tree lifecycle and original
story/hardware acceptance remain open. Full Gen1 parity is unproven.

Behavior was checked against the read-only Gen1 reference
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` and primary disassembly sources:
[Gold selection/table](https://github.com/pret/pokegold/blob/master/engine/menus/menu_2.asm),
[Gold handover](https://github.com/pret/pokegold/blob/master/engine/events/specials.asm),
[Crystal selection/quantity](https://github.com/pret/pokecrystal/blob/master/engine/events/kurt.asm),
[Crystal recipe table](https://github.com/pret/pokecrystal/blob/master/data/items/apricorn_balls.asm).
These links identify behavior/provenance; no ROM or extracted table bytes are
included in the contribution.

Original contributions by Roxas2712; existing reference, upstream and
third-party rights and credits remain applicable. See the [specific PR contribution permission and credits](https://github.com/Roxas2712/Gen2Recomped/blob/7867399c753186778bd4b8816ba37573357e4b40/LICENSE-ROXAS2712.md).
