# Native colour/depth shader variants

On Metal, a projected alpha-cutout program needs late fragment-depth writes
when a real writable depth attachment is bound. Colour-only targets cannot
use that output. The bounded shader compiler now caches separate variants
for those actual native targets and compiles each through the exact original
constructor. It does not create a second cutout companion for every variant.
The public shader remains the original userdata; successful native uniform
writes, return values, resource ownership, push/pop and release remain owned
by the existing native interfaces.

The alpha-depth adapter lazily hooks the native Shader class. Earlier live
programs can rebase across that precise engine-owned interposition only when
the exact preceding methods match. An intervening foreign value owner keeps
the conservative original-program path. A later native wrapper cannot hide it.
Sampler retention helpers are declared before use and defined after the source,
so valid late sampler declarations also compile without moving user code.

Qualification on Apple M3 / native LOVE12 Metal:

- Current fork source22928688 includes maina8833b35. Its actual native contract
  passes96 checks, including independent explicit-depth pixels, transparent
  holes, opaque occlusion, colour/depth/colour reuse, an earlier live shader,
  mutable uniforms, a deliberately wrong-value control, and native lifetime.
- The foreign-owner fixture passes79 checks on the attested implementation.
  An owned negative host using the weaker ownership predicate fails the
  original-program ownership assertion. This is an ownership counterexample;
  its preceding pixel comparisons passed, so it is not a pixel counterexample.
- Focused CPU checks pass: alpha depth69, sampler guard16, planning48 and
  platform policy40. The existing canvas adapter128 checks also passed.
- A full current-main native source regression and actual unchanged-consumer
  Third-Person/rain throughput comparison are recorded separately when terminal.

This change has no60FPS acceptance claim. Before it, the isolated real rainy
Third-Person view averaged68.409ms per warm frame (about14.6FPS), with roughly
61.952ms in drawing and5370 indexed native draws. Reflection functionality
passed all six clear/rain and normal/third/first cases on the preceding source;
that does not establish adequate throughput. No graphics quality, native map
rules, private mod files or player profiles are changed.

Original contributions by Roxas2712, under LICENSE-ROXAS2712.md. Existing
upstream and third-party licences and rights remain in effect.
