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

- Current fork source 22928688 includes main a8833b35. Its actual native contract
  passes 96 checks, including independent explicit-depth pixels, transparent
  holes, opaque occlusion, colour/depth/colour reuse, an earlier live shader,
  mutable uniforms, a deliberately wrong-value control, and native lifetime.
- The foreign-owner fixture passes 79 checks on the attested implementation.
  An owned negative host using the weaker ownership predicate fails the
  original-program ownership assertion. This is an ownership counterexample;
  its preceding pixel comparisons passed, so it is not a pixel counterexample.
- Focused CPU checks pass: alpha depth 69, sampler guard 16, planning 48 and
  platform policy 40. The existing canvas adapter 128 checks also passed.
- Full native source regression: all 252 groups pass on combined source
  22928688 with main a8833b35 (frozen receipt eb45d719ba). The actual
  unchanged-consumer Third-Person/rain run (receipt 9ab9ec7c4a, unchanged private
  bddb51819c) completes 120 sampled and 120 unprofiled warm frames. Warm mean:
  59.712 ms (about 16.7 FPS), draw 53.697 ms, update 4.555 ms. A cold frame still
  takes 3133.971 ms during native shader compilation; this hitch is unresolved.
  The real field program is active, but the paper-surface option is false,
  fieldIndexSourceBytes is 0 and packed ranges are not active. There are still
  5370 indexed native draws. No competing test children ran in this window.

This change has no 60 FPS acceptance claim. Before it, the isolated real rainy
Third-Person view averaged 68.409 ms per warm frame (about 14.6 FPS), with roughly
61.952 ms in drawing and 5370 indexed native draws. Reflection functionality
passed all six clear/rain and normal/third/first cases on the preceding source;
that does not establish adequate throughput. No graphics quality, native map
rules, private mod files or player profiles are changed.

Original contributions by Roxas2712, under LICENSE-ROXAS2712.md. Existing
upstream and third-party licences and rights remain in effect.
