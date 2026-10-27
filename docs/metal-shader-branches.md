# Bounded Metal shader branch specialization

Large world programs can keep expensive lighting/material branches dynamic even
when their scalar controls stay at zero or one. On Apple-silicon macOS with
LÖVE 12/Metal, the native compiler adapter specializes eligible `if` reads of
positive float zero/one and booleans. It preserves declarations, arithmetic,
source artwork, render resolution and post-processing. It uses no mod names or
private shader snippets. Other backends, smaller programs and unsupported
source/value shapes keep their original programs.

The caller retains the real original Shader userdata and interface. Every
successful `send`/`sendColor` updates that C shader first; original errors,
return arity and nil values remain intact. Bounded immutable snapshots preserve
partial uniform-array tails and per-send matrix layout. Eager variant writes
preserve batch ordering and release replaced C texture references. Missing or
released replay resources, mutable Data, buffers and unknown values fall back
to the original. A later foreign Shader-method owner also disables optimization.

An unnamed Channel holds the original C shader without keeping its Lua userdata
alive. Retirement queries the real native graphics-stack depth, including raw C
push/pop calls. Disabled/orphan records retire only at an empty-stack boundary;
hidden native stack frames keep their mappings and C leases. Public `getShader`
returns the original live interface, including native reconstruction after
explicit release. No public reference-count API is assumed.

Sampler declarations remain visible to the Metal stage linker behind a private
zero-valued guard. Vertex-only declarations stay in their stage; unsupported
syntax or compilation failure retains the original program. The optional canvas
compatibility adapter provides its preceding constructor as `compileNative`:
derived programs must not have their already admitted clip convention analyzed
again after their forwarding entry is modified. An older installed adapter
without this seam leaves specialization disabled. No producer macro is injected.

Limits: 64–256 KiB per eligible source, 16 live sources, 2 MiB combined source,
16 variants per source, 64 live variants, 256 observed uniforms and 32,768
snapshot nodes per source. Source shadowing/macros and unsupported shapes stay
conservative. `POKEPORT_SHADER_BRANCHES=0` restores the original compiler path.

## Native qualification

Frozen native source `6f82c5cb00`, fork main `f8a05682` plus the compatibility
composition, unchanged private Origami 1.0.9 `ae59c77c`: baseline `a2aac5b097`
versus native adapter `55614c8cc0`. Both use actual Metal on M3/16 GB, High,
1024×768 scene/window, active FXAA, render scale one, supersampling off and
native VSync off. No QA Shader prototype is installed.

Each row measures 120 ordinary native walking frames, after settling and a
separate collection/recovery test. Native frame serial increments once per
sample. The shared hardware lease covers source setup through final cleanup.
This initial deterministic driver calls the Game update body directly. A
follow-up through the complete native `PlatformHooks.update` frame owner is
required before treating these figures as full mod-update measurements.

| View | Original mean ms | Adapter mean ms | Adapter p95 ms | Adapter max ms |
| --- | ---: | ---: | ---: | ---: |
| open | 5.69 | 5.32 | 6.87 | 9.39 |
| third | 18.98 | 11.43 | 12.87 | 15.10 |
| first | 20.02 | 11.86 | 12.83 | 14.12 |

All three complete scene captures are pixel-exact, excluding only the changing
FPS HUD (`x >= 890 && y < 56`). Twelve actual variants are used, with no
compiler/replay failures, unsupported values or fallback draws. The original
failed native integration (`a67197449f`) double-adapted clip space; its failure
is preserved and corrected through the constructor seam, not an image flip.

Actual GPU fixture `5155a3c3f4` passes 72 checks, including spatial projection,
real Shader identity, multiple/nil returns from a prior owner, partial arrays,
matrix layout, mutable color inputs, sampler release, raw native stack frames,
Shader release/GC, Data fallback, source caps and later foreign method ownership.
The deliberate wrong-branch pixel control is detected. Focused native engine,
orientation, JIT, map, follower, options, pacing and Crystal VRAM checks pass in
the same frozen composition.

These are internal rendering observations while the console is locked. They
are not OS-window, interactive 60-FPS, outdoor, full-game or all-platform
acceptance. Cold compilation is synchronous: 7.21 seconds accumulated across
the twelve first-used variants in this run, outside the steady walking samples.
First-use hitches remain a limitation; there is no asynchronous-compilation
claim. Player profiles and saves are not used. QA enforces 20 GiB free, above
the requested 8 GiB minimum.

## Repeating the API fixture

`tests/native_shader` is a ROM-free LÖVE fixture. Its engine root comes from
`SHADER_TEST_ENGINE` (default: the repository containing the fixture); a frozen
runner must set it to the exact copied source. Use a disposable QA identity,
the project's managed storage/hardware runner and Metal. Set
`QA_NATIVE_SHADER_ADAPTER=1`; `QA_SHADER_MULTIPLE_RETURNS=1` additionally exercises
an existing method owner. `QA_SHADER_WRONG_COMPILER=1` deliberately re-enters the
actual canvas adapter and must fail the spatial pixel comparison. That negative
requires the canvas adapter; the standalone compiler fixture also runs without
it. Never use a player identity for this fixture.

Contributions by Roxas2712 — https://github.com/Roxas2712.
See [the contribution terms](../LICENSE-ROXAS2712.md) for Cedric / UNDERdecoded's
specific incorporation permission and applicable credit requirements. Existing
notices remain intact.
