# Native Gen2 battle window owner

The actual shared Gen2 battle screen exposed `drawScene` and `drawPanel`,
but had no `drawWidescreen`. A source-unchanged presentation consumer could
stage a scene and later fail its complete native redraw with
`native Gen-2 battle screen is unavailable`. On preceding source
`066b73c1`, an actual Metal test passed54 functional checks and produced12
inspected OS-window captures, but battle/menu-message frames remained white.
Read-only receipts showed the missing method, a latched compositor fallback,
and587 earlier completed scene frames. This is not a graphics acceptance.

`Gen2BattleWindow` installs the public drawer on the actual battle class.
Its `drawsWidescreen` predicate opts in only on Gen2, so shared Gen1/Gen3
screens retain their existing canvas route. Classic composition calls the
actual `drawScene` through existing native Gen2 chrome; wide composition
uses the existing WideBattle scene. The native layout and existing
`battleFit` option determine panel dimensions and fixed/fill scaling.
Fixed sizing uses the existing physical-pixel/DPI grid and playfield bounds.

The existing GraphicsScope owns the complete window call, including errors,
canvas changes and nested leaked pushes. The drawer neither changes battle
state nor advances its queue, typewriter, HP animation or input.

The native public contract was checked against Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`,
`src/ui/gen2/BattleState.lua` (`panelSize`, `battlePanelScale`,
`drawsWidescreen`, `drawWidescreen`). Existing project rights and notices
remain applicable; see `NOTICE.md`.

`tests/engine/gen2_battle_window.lua` exercises actual compositor admission,
classic/wide scene ownership, fixed/fill sizing at multiple viewports and
DPI ratios, and failed-scene restoration. It includes all five supported
Gen2 editions and checks that Red/FireRed/Emerald do not acquire the Gen2
window route. Passing source tests alone does not establish a fixed white
view, complete Gen1 presentation parity or release qualification. A new
unchanged-client GPU run is required.
