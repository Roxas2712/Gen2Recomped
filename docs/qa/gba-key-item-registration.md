# GBA registered key-item controls

Emerald and FireRed/LeafGreen previously offered REGISTER for every key item,
including quest items whose cartridge records disallow it. SELECT inside the
bag did nothing. FireRed/LeafGreen also omitted the REGISTER/DESELECT action
pair from their imported menu metadata, so the action label never changed.

The item extractor now preserves the independent `gItems[].registrability`
byte at offset 25. A GBA-only cache revision requires a fresh own-cartridge
import; other generations retain their markers and existing saves remain in
their current format. The bag and overworld shortcut share one eligibility
check. Emerald/FRLG require both the key-pocket action and the item's byte.
RS retains its existing pocket-wide REGISTER action and SELECT reordering.

SELECT toggles the actual selected Emerald/FRLG key item only in the field
bag. Battle, selection callbacks, shops, PC operations and tutorials cannot
change registration through that button. Dispatch also rechecks that the
item is still held. Nonregistrable actions retain Emerald's grid holes and
compact FRLG's single-column list. Host item IDs, names and counts remain
unchanged; registered IDs continue through the existing save serializer.

The independently implemented adapter follows the control contract in
Gen1Recomp `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`,
`src/ui/game3/bag_menu.lua`, `rse/bag_menu.lua` and `rs/bag_menu.lua`.
This change does not establish complete bag-layout parity or complete story
acceptance for any edition.

## Validation scope

`tests/engine/gba_key_item_registration.lua` exercises the actual item-table
reader, all-five eligibility/action rules, field SELECT, forbidden contexts,
stale selections, serialization and edition-specific cache markers.
`tests/gba_key_registration_native_driver.lua` prepares private own-cartridge
key items and drives the real bag with ordinary buttons. It checks quest-item
actions, the registered badge, the applicable DESELECT label, disk save/load,
SELECT clearing and RS's separate reorder mode. These prepared fixtures are
not ordinary story progress. Final native and CI results belong in the pull
request after execution; no ROMs, generated resources or private saves are
included here.
