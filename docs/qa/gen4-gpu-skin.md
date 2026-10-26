# Gen4 GPU skinning qualification

GPU skinning uses a dense palette of at most sixteen source joint slots. Disabling `gen4GpuSkin`, or exceeding sixteen distinct slots, retains CPU skinning. Packed vertex and GPU lighting switches remain independent.

The actual Metal host now draws skinned geometry into an owned colour/depth target, rather than accidentally using a window without a depth buffer. CPU/GPU comparisons cover identity, translated joints, sparse slot numbers, per-vertex transforms, missing joints and shape-placement fallback, with cached and unconditional uniforms. Palette overflow keeps CPU bind vertices.

All 132 actual GPU assertions and 22 frame comparisons passed on Apple M2 / LÖVE 12 Metal; maximum byte delta was zero. This is synthetic geometry, not a full Twinleaf scene or physical handheld measurement. All 53 native suites, packed/light checks, the switch matrix, gallery/hooks, pinned API3 and unchanged external fixtures passed in the same stable-source run (130 runs). See the JSON reports. No gameplay frame-time improvement is claimed before the integrated baseline.
