# Native GBA UI drawing pass

`src.ui.game3.ui_pass.drawUi()` borrows the current native modal draw phase.
The function takes no arguments. Calling it between native phases does not
paint a second frame. Repeated base calls inside a wrapper share one native
result, including failures and trailing nils.

The native Game painter retains its state order, visibility, surface fitting
and centering. World owners, admitted battles and states explicitly marked
`isOverworld` or `isBattleState` retain their own render passes. Contiguous
ordinary overlay groups use the UI boundary; interleaved scene owners split
the groups without reordering them. Existing native UI controllers continue
to own input and logic. Unpatched modules keep the direct native painter.

A wrapper may redirect its borrowed UI group to an owned canvas. Graphics
scope restoration covers canvas, shader, transforms, blend/color, stack and
physical scissor, including mixed pixel densities and callback failures.
Replacing the Game data, save, loader, stack or any stack member invalidates
the already resolved UI phase. Native drawers run under their native owner;
the source wrapper keeps its own callback attribution.

This is a drawing contract. It neither allocates HUD targets nor advertises
the complete battle-presentation protocol. Help controllers, full unchanged
mod gameplay, map/terrarium visual acceptance and interactive frame rates
require their own evidence.

Validation entry points are `tests/engine/native_ui_pass.lua` and
`tools/native-ui-pass-gpu`. The GPU fixture captures the actual compositor
through the existing final-output owner, compares default/wrapped frames,
checks independent UI rectangles at DPI 1/2, rejects a displaced positive
control and checks physical clipping after a source error. It does not
establish OS-window or gameplay acceptance.
