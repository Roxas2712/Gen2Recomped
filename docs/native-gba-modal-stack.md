# Native GBA modal ownership

`src.ui.game3.stack` now describes modal UI on the current native Gen3
`Game.stack`. It keeps the actual world and battle controllers outside its
menu list. Registered API-3 screens expose their actual state under
`layer.mod.state`; legacy menu modules receive the real native input object
and execute through the same native update/draw clock.

Named close/reopen and clear remove actual states and run their native exits
and screen events. Clear detaches its original selection before callbacks,
so a screen opened during an exit survives. An exit failure does not prevent
remaining selected states from cleaning up. Covering menus close actual stay
text without completing ordinary native script prompts.

Preview `_layers` suspension preserves state and layer identity without
exiting or entering a menu. Owned leases reject another map, root, save or
session, duplicate or retired rows and malformed arrays before changing the
native stack. Copying a layer array cannot bypass scene ownership. Reload
cannot expose the previous game's UI. Gen2 cannot mutate its stack through
this GBA API.

Draw ordering, `hideBelow`, `drawUnder` and live fullscreen predicates feed
native rendering. Main-screen mirroring still respects `screen.render_visible`
without changing input ownership. A hidden fullscreen menu reveals the lower
native scene on that surface. Legacy GBA widgets request the native 240×160
surface, avoiding the Game Boy overlay offset.

## Evidence

The [source-bound receipt](qa/native-foundation/gba-modal-stack.json) records
four separate macOS hardware-GPU runs of committed source `8afbf422`:
FireRed and Emerald, each on Metal and OpenGL, normal VSync 1. Each run checks
actual registered screen input/nesting, suspension/restoration, clear, a
legacy GBA modal over the actual native battle, native escape and return to
the same map. All 16 fresh owned-window proofs pass; inspected text is upright.
These are functional tests using an engine QA mod, not original OASC rendering.
The fresh unsaved map entry bypasses the introduction and is not story testing.
The proof called `resized` shows the battle modal; it is not a window resize.

There are 116 native ownership/lifecycle checks and 94 shared-consumer checks.
The same unchanged 46-check consumer runs against both actual native engines,
separately for FireRed and Emerald, with equal results. The public Gen1
reference is pinned to `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` and remains
separate from the protected installation. CI repeats that comparison. The
standalone upstream patch also passes native visibility/routing tests; both
new suites fail against the source preceding the feature.

Windows/macOS QA packages contain identical verified engine payloads. Windows
PE/DLL and macOS signature/source checks pass; Windows hardware execution has
not been tested. The existing public preview remains unchanged.

## Remaining original OASC requirements

The original unchanged OASC mod now passes its first missing import,
`src.ui.game3.stack`, and fails next at `src.core.game3.map` in the real SDK
fixture loader. This also holds for the newer private reference `cef4a9ef`.
Its six changed files concern Hoenn interior healing/camera behavior; the
manifest, entry point and native map/stack source are unchanged from the
previous GPU-tested reference `aa7e6061`. The newer mod is not claimed as a
full GPU-tested original reference.

The next work concerns actual native map/player/atlas records, neighboring-map
residency and field handoffs, followed by renderer and battle integration.
Passing an import alone does not establish native OASC compatibility. The
mod port remains paused; the existing Gen1 and player installations are unused.
