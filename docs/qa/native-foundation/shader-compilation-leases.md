# Per-source optional compilation leases

`ShaderSpecialization.pauseCompilation(shader)` returns a release function for
an admitted original Shader, or nil when the optional adapter does not own it.
While any lease is held, a missing specialization key draws with the original
native shader. Existing cached variants remain available. All ordinary native
uniform writes, resource ownership and fallback checks retain their behavior.

Leases nest independently and release once. Callers release them at their
loading/lifecycle boundary. Other shader sources retain their original policy;
the default permits compilation until a consumer explicitly acquires a lease.
The API does not defer original Shader construction or promise asynchronous GPU
compilation. `deferredVariantDraws`, `lastCompileKey` and `lastCompileSeconds`
provide bounded diagnostics.

Motivation: one native reflection trial recorded three new optional variants
and 417 ms of compilation in a 465 ms frame. A separate consumer may keep its
loading window open, then pause optional compilation during interactive drawing
without changing shader output or tuning garbage collection/JIT settings.

The CPU contract exercises nested leases, live values and array tails, cached
keys, unrelated shaders and source retirement. Native pixel qualification is
performed separately by the owning QA host.
