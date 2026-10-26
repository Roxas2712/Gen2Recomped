# Completed link-battle parties

`link.battle_ended` runs when the native LinkState regains ownership after an
admitted cable battle. It precedes `link.ended` and releases the completed
battle handle even if no mod subscribes. This also covers the fork's Arena
entry through LinkState. It does not invent completion events for a cancelled
party exchange, a spectator or a separate tournament-controller path.

The payload contains:

| Field | Meaning |
| --- | --- |
| `result` | Native result, or `"ended"` when no result was set |
| `role` | Local participant: `"host"` or `"guest"` |
| `peerName` | Negotiated opponent name, when present |
| `myParty` | Local battle copies, including the bench and final HP/PP |
| `theirParty` | Opponent battle copies in the local participant's perspective |

Cable combat uses disposable parties. The event observes those copies rather
than the saved adventure team. Native API 1/2 callbacks receive the actual
completed battle-party objects. Unified API 2/3 callbacks receive detached
Pokemon records for each listener; edits to those notifications do not write
to another listener, the native battle or the adventure save. Both unified
forms of this additive event use the reference's short status identifiers,
such as `PSN`. Existing API-2 events retain their previous status conventions.

The [portable example](../examples/portable_link_result/main.lua) uses the
same consumer source on both engines. Its API-3 manifest uses capability
discovery; older entry APIs without `mod.supports` can still subscribe.

## Qualification

`luajit tests/engine/link_battle_ended.lua` exercises actual LinkState party
admission, native battle teardown and session cleanup on all eleven supported
GB/GBA editions with synthetic parties. It includes both roles, win/lose/draw,
explicit and absent-result endings, bench HP/PP, unchanged adventure teams,
native object identity, detached unified records, independent listeners,
once/unsubscribe and owner removal. It does not contact an external peer or
load a player profile or ROM.

Run `tests/link_result/worker.lua` from either engine checkout, passing this
checkout, version, API and callback format. On clean read-only Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, native API 1/2 and unified API 2/3
on Red and Gold produce eighty paired typed observations equal to this fork.
The fixture uses each engine's own transport/Session rather than replacing
the completion producer. The source reference's native LinkState producer
defines the payload and notification order.

These are prepared completion scenes and shared-contract checks. They do
not establish real-network reliability, every link mode, physical hardware
acceptance or complete unchanged-mod gameplay. Engine-wide regression and
release-package qualification are recorded separately at their exact refs.
