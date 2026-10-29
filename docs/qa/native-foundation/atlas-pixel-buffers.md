# Bounded CPU pixel buffers (candidate, default off)

Set `model.packedProjection=true` only for explicit comparison. The ordinary
model path remains unchanged by default. Eligible projections reuse private
256-byte index planes and a 1-KiB RGBA scratch buffer; returned strings own
their bytes. Palette bytes, flips, layer ownership, padding and dirty-slot
semantics remain unchanged. This is CPU work, with no GPU readback or clock
change.

Unknown decoder methods, tile-cache owners, helper methods, missing FFI,
unsupported palette values and cooperative checkpoints retain the ordinary
projection path. Short index strings never reach pointer reads. Worker
admission includes the pixel-buffer helper owner.

`tests/engine/native_atlas_pixel_buffers.lua` compares five editions, indexed
and RGBA planes, palette reverse indices, animation/palette transitions,
foreign helpers and immutable returned bytes. A 180-cell animation burst is
timed in ABBA order. Preliminary operation timings vary substantially but
show less CPU work; they do not establish a whole-game FPS improvement.
Native full-scene and combined-feature comparisons remain required before
activation.
