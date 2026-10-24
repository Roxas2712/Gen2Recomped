# Remaining OpenGL spikes and the native preview

The long FireRed replay still shows spikes dominated by **synchronous GPU
readback**, rather than Lua collection. At 1280×960 the worst sampled frames
spend roughly 10–14 ms in readback; at 1920×1440 one bedroom frame spends about
19.9 of 22.4 ms there. Recorded collector work in those frames is much smaller.
The existing BGRA and palette optimizations reduce avoidable CPU work but do
not eliminate driver/compositor waits. **The remaining large spikes are open.**

Three additional approaches were tested only in independent fork exports:

- Native `glReadPixels` matches 1,230,848 reference bytes, but gives mixed tail
  results; the larger bedroom render P99 rises from 11.89 to 12.90 ms. It is
  not integrated into the engine.
- Updating or reattaching the own process's OpenGL context, including a
  non-layered view, still leaves the default framebuffer undefined. No context
  manipulation is shipped. One prototype selector-argument error was corrected
  and the failed child exited; the corrected attempts also do not repair it.
- Reusing three native presenter descriptors removes repeated construction in
  its boundary test, but the complete AB/BA comparison is mixed in FireRed and
  markedly worse in Emerald. Despite functional pixel/window checks, it is
  withdrawn. Source tests and renderer code are restored to `bf1ab0f`.

The [metadata report](qa/native-foundation/opengl-spikes-preview.json) retains
all eight primary trials, 19,200 timed frames and 32 own-window proofs, plus
per-frame tail records, matched canonical NPC/stack signatures, negative
results and proposal decisions. Each primary scene has 600 warmup/600 measured
frames, two maps and actual 1280×960/1920×1440 pixels. No timed screenshots or
observers are used. Source exports omit mods and disable discovery. These are
one-host observations, not a claim to identify every earlier timing swing.

The Windows/macOS [native preview](native-preview-release.md) therefore ships
the previously verified renderer and all accumulated foundation/import/cache
fixes, with a new isolated preview profile. It does **not** ship the rejected
proposals or claim that the remaining GPU stalls are fixed. Hardware feedback
from Omegadias can now use a reproducible runtime and source commit without
changing an existing installation. Native Windows gameplay is an external
test step; local macOS execution is checked separately on the actual package.

The Origami port remains paused. Gen1 and the protected player instance are
untouched. Prototype captures, ROM bytes, generated caches, local paths and
process/window identities remain private.
