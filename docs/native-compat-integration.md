# Native compatibility foundation integration

This fork integration reuses the committed native engine work at `836b7dce`
(the compatibility changes after `f8c9d684`). The active sprite-runtime work
after that snapshot is separate. The existing native simulation, saves,
movement phases and map identities remain their owners.

| Boundary | Existing upstream review |
| --- | --- |
| Map identities, source attributes and terrain views | #239, #245, #246, #251 |
| Semantic tileset identities and owned atlas resources | #250, #260 |
| Player phases and collision observations | #254, #255 |
| Session and frame callback ownership | #265 |
| Object views and original sprite sheets | #266, #269 |
| Owned original-order sprite runtime | #276 |

These existing reviews should be reused. This integration does not submit
another copy of those contributions upstream.

## Combining the contracts

The fork already has native map names and live `layout_native` handles. Keep
those implementations and their existing native-grid checks. Compatibility
snapshots use `src.compat.gen1.DecodedLayout` instead: a classified collision
byte, partial cell or detached revision is not the native map's raw collision
field or revision. Snapshot edits cannot change the native walking grid.
Transparent selection of the older decoded constructor for unchanged callers
of `src.core.game3.layout_native` still needs its own compatibility boundary;
the snapshot consumer alone does not prove that import contract.

Native forced movement still runs before ordinary input. Compatibility player
wrappers enter the existing GBA player phase. Loader retirement retains the
fork's worker, step and API cleanup while also retiring map/session resources.
The launcher's native overlay retains its mouse-motion guard.

## Graphics evidence and remaining work

Source borders, connection offsets, original metatile attributes, palette
words and sprite-frame dimensions/anchors are retained alongside normalized
native outputs. Map views and connection placements use 16-pixel GBA cells;
32-pixel block assumptions must not change room extents. Authored padding and
true map dimensions remain separate, with padded collision kept outside the
walking crop. Original sprite image tables preserve poses that normalization
can reorder or separate into another sheet.

The imported historical receipts identify their exact source snapshots; they
are not receipts for this newly composed fork. Run the full engine/SDK suites
and scoped consumers on the composed source before integration. Real GPU
comparison, complete original-mod startup, camera/battle/UI presentation,
save/restart gameplay and physical mobile/console acceptance remain open.
Party, bag, storage, dex and script-store schema completion also remains open.

The sprite follow-up reuses source `343e3260` and schema-2 object caches. It
adds owned original-order resources, native asset override projection, pose
observations and bounded stream preparation. Old caches request the native
re-import path; the integration does not modify mod packages or player saves.
Its composed regressions and fresh original-entry probes must pass separately
from the earlier map/session receipt. The numeric script-store work after that
source snapshot is not included in this follow-up.
