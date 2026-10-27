# Native move metadata for Gen2 presentation

The live Gen2 battle model now exposes `moveDef(id)`, delegating to the native
screen's current catalog authority. Move cards can read native names, types and
base PP instead of falling back to raw IDs and missing maximum PP. The bound
reader is stable and does not copy a move or freeze a catalog row at battle entry.

The shared native resolver accepts a catalog ID as well as its existing move
instance input. Instance-specific Struggle handling remains on the existing
path. This adds no presentation-client patch, alternate controller, PP writer
or separate move catalog. Native move-list/turn ownership remains unchanged.
