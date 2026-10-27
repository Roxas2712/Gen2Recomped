# Persistent native world admission

Native session observations resolve an explicit entry-world scope first,
then a world stored in the physical state list, then that stack's admitted
`worldState`. A persistent world is independent of the overlay list; an empty
list or a covering menu does not remove its map/player observations.

Input still belongs to the native stack's active state. An uncovered
persistent world accepts input; a covering menu keeps it, including when
that menu is hidden only for rendering. Dataset/map identity checks remain
required. A modern empty stack cannot revive an unadmitted `game.overworld`
pointer. Legacy tool hosts without a physical state list keep their explicit
world fallback.

The owner publishes `phase = "boot"` until native world entry succeeds, then
`phase = "play"`, including while menus cover that world. Clearing the world
returns the owner to boot; a failed or retired entry cannot publish play.
`acceptsMenuInput()` observes whether the underlying field has settled even
under an overlay, so content installers can request a safe save and restart.
Scripts, battles, transitions and actor locks still reject that query. Native
movement continues to use the overlay-sensitive `busy()` check and remains
blocked until the menu closes.

The initial five-edition regression reproduced 50 failed assertions. The
expanded suite passes 150 checks. It uses the actual native StateStack and player
with synthetic map data, including native field-move entry/retirement over a
persistent world, covering UI, stale datasets and failed entry scopes. This
does not establish original mod initialization, full rendering or gameplay.
