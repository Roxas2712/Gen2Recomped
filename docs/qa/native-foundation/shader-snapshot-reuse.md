# Bounded shader snapshot reuse

The optional native shader specialization adapter used to allocate a complete
owned value tree for every successful uniform write. Repeated vector and matrix
uploads can now reuse one detached, overwritten snapshot per source. The native
setter and eager writes to existing variants still execute on every send.

Longer array prefixes remain owned by the replay bank until overwritten; they
are never recycled early. Reused trees discard old tails, reject sparse input,
copy mutable caller tables, and retain weak texture references. A source keeps
at most one spare row, within the existing 32,768-node snapshot bound. Unsupported
values continue to use the original native shader.

`ShaderSpecialization.recycleSnapshots=true` opts into the candidate; it is off
by default pending native scene qualification. The false setting retains the
allocation control path. It does not change graphics output or tune garbage collection.

Validation: `tests/engine/shader_snapshot_reuse.lua` compares original and variant
values through changing prefixes, caller mutations, variant switches, matrix
layouts, textures and unsupported inputs. Its CPU operation benchmark reports
both orders of an allocation/reuse comparison; this is not a whole-game FPS
claim. The candidate also passed the 44-group current-main performance source
suite. Actual scene qualification is recorded separately.
