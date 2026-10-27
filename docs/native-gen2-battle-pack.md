# Native Gen2 battle PACK

Gen2 battle ITEM previously opened the shared `BagMenu` list. The native Gen2
screen contract uses `Gen2PackMenu`, with cartridge pockets, battle eligibility,
cursor persistence and a selection continuation. Presentation clients treat
these surfaces differently; a list-only skin can otherwise be applied to the
pack graphics and produce unreadable mixed surfaces.

Gen2 now constructs the actual PACK through the existing battle UI queue. Its
field world is deliberately empty, as on the Gen1Recomp Gen2 controller, so a
battle item cannot fall through to a live field action. Selection delegates to
the existing `BagMenu.useItem` target/effect/turn path with the real PACK as the
close/rebuild owner. Item effects and enemy turns are not duplicated.

ROM-free regression coverage drives ITEM, pocket navigation, cancellation and
actual potion/target input through the real native classes. It verifies no
action on cancel, one inventory consumption, healing, preserved move PP, one
enemy response and clean stack ownership across all five native Gen2 editions.
Other generations retain their bag path. GPU/client readability and the final
package require separate acceptance.
