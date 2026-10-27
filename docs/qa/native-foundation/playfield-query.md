# Native playfield cutout query

`src.render.Playfield.cutout(width, height)` observes the rectangle reserved by
the existing native `GameViewport` during its current frame. This is the lazy
query required by unchanged battle/menu layout consumers; it does not install
a skin, allocate a target, change a scissor or begin another viewport phase.

Explicit full-window dimensions return the native rectangle in window space.
Dimensions of the already entered native target return local origin `(0,0)`
and its actual extent. This avoids subtracting the same window offset twice.
Logical dimensions do not change with DPI. Unrelated preview/actor target
sizes, invalid dimensions, a retired frame and the ordinary full-window path
return no reserved cutout, preserving the caller's safe-area/touch fallback.

Only `cutout` is offered. The independent `push`/`pop`/skin-owner protocol is
not advertised. Native Gen2 rendering still enters and exits its existing
viewport directly.

The actual unchanged-package native battle probe `cf9cd39d2b-firered` reaches
native entry but fails before scene frames because this module was absent.
Keep that failed receipt; CPU geometry checks alone do not qualify the later
map/terrarium frame, physical-window output, portrait touch play or FPS.
