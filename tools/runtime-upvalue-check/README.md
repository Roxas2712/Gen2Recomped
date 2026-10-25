# Experimental runtime upvalue qualification

The native engine's current stock LÖVE runtime accepts at most 60 captured
locals per Lua function. A supplied Gen2 structural renderer extension exceeds
that limit, although its original base module compiles. Increasing the engine
API surface cannot make that generated function compile in a VM with the same
limit.

The patch here is an **experimental dependency patch**, not an engine-side
source rewriter. It applies to LuaJIT commit
`a4c064539ea931274d407e1249b4bb575424a0f4` and raises `LJ_MAX_UPVAL` to 120.
The recorder's own source notes a 127 limit; this is not proof that every
architecture is safe at 120. The normal runtime/release is not replaced by
these tools. No supplied renderer source/assets or cartridge data are included.

Always use a separate clean dependency checkout/build directory. On macOS the
local experiment builds with `MACOSX_DEPLOYMENT_TARGET=11.0` and
`make -j4 XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT`. Its LÖVE test app is a separate
copy with an arm64-only replacement Lua framework and ad-hoc signing. The
original stock app and dependency checkout remain unchanged. This is not a
universal macOS or Windows release recipe.

From the engine repository root, run both interpreters:

```sh
/path/to/stock/luajit tools/runtime-upvalue-check/check.lua 60
/path/to/experimental/luajit tools/runtime-upvalue-check/check.lua 120
```

The ROM-free Lua probe exercises interpreter and JIT calls, shared sibling
captures, repeated full GC, high-index debug reads/writes and bytecode round
trips at 1, 8, 32, 60, 61, 64, 96 and 120 captures. Unsupported counts above the
selected minimum are reported; rejection at/below the requested minimum fails.
Debug replacement of constant upvalues flushes existing traces first, matching
[stock LuaJIT's debug-surgery behavior](https://github.com/LuaJIT/LuaJIT/issues/968).
An earlier probe omitted that flush and failed at 64 in its JIT phase; that
result is retained as an invalid test assumption, not a successful VM result
or a reason to silently disable JIT for large closures.

Compile `c_api.c` against the *same candidate headers and static library*, then
run it with 60, 61, 64, 96 and 120 as arguments. It pushes those captures through
the actual Lua C API, repeatedly invokes the C closure and collects garbage.
For example on macOS:

```sh
cc -I/path/to/candidate/src tools/runtime-upvalue-check/c_api.c \
  /path/to/candidate/src/libluajit.a -lm -o /path/to/own-output/c-api-upvalues
/path/to/own-output/c-api-upvalues 120
```

These microchecks must accompany engine regressions and real GPU verification.
A generated extension compiling/initializing is not proof that all its Pokemon
models, movement, combat, shadows and other effects are equivalent to Gen1.
Windows/x64, Intel macOS, architecture packaging, dependency ABI compatibility,
bytecode interchange and broader native renderer/gameplay coverage remain
release gates. See the source-bound runtime experiment receipt under
`docs/qa/native-foundation/` for completed local evidence and exact limits.
