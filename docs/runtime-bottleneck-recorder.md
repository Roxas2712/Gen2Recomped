# Runtime bottleneck recorder

`tools/runtime_bottleneck.lua` is an explicit QA-driver utility. It is not
required by startup or installed in the game loop. Use it on an owned QA
identity after the real scene has finished preparing. Keep the normal native
clocks, camera, simulation and graphics settings running.

The caller supplies an idle LuaJIT `jit.profile` instance, a yielding frame
wait, a monotonic clock, and a read-only observer returning a fresh table:

```lua
local capture = assert(loadfile('tools/runtime_bottleneck.lua'))().capture
local result = capture {
    profiler = require('jit.profile'),
    clock = love.timer.getTime,
    wait = waitFrames,
    frames = 240,
    observe = function()
        local stats = love.graphics.getStats()
        return {focused = love.window.hasFocus(), drawcalls = stats.drawcalls}
    end,
}
-- Serialize result only after capture returns, outside timing intervals.
```

The report contains per-frame intervals and observer fields, VM-state sample
counts, self locations including source lines, inclusive functions, call
stacks and the 30 slowest observed frames. Recursive functions count once
per inclusive sample. Captures are bounded to 600 frames, 4,096 keys per
category, 16 stack levels and 2,048 bytes per key. Overflow sample
counts remain visible. Observer and driver errors stop the sampler before
propagating the original failure. The caller must own the profiler for the
duration of the capture. Sampling defaults to 5 ms function sampling, with
source lines read from available stack metadata. `intervalMs` accepts 5–100 ms.
Capture stops after 15 seconds by default (`seconds` accepts 1–30), preserving
completed frames. A native profiler fault can prevent the callback returning;
the external QA process must also have a hard timeout. Validate the native
profiler independently before attaching it to a complete scene.

No GPU fences, readbacks, collections, JIT configuration, rendering changes
or disk writes are introduced by the recorder. Sampling and observers still
add overhead: these reports always declare `qualifiedFps=false`. Sampling
shares describe sampled wall time, including native calls and waits; they
are not GPU execution times or process CPU percentages. Inclusive shares
overlap and must not be summed. A long present/drawable wait alone does not
identify which GPU pass caused it.

Analyze a saved capture, including one nested in a larger consumer report:

```sh
python3 tools/analyze_runtime_bottleneck.py capture.json
python3 tools/analyze_runtime_bottleneck.py capture.json --json
```

The analyzer also accepts diagnostic `legs` containing `name` and `frames`.
It groups reverse-order `-A`/`-B` cases and reports mean, median, p95, maximum,
focus counts and available update/draw/present/call counters. Unfocused or
slow frames remain in the evidence. Graphics cuts are diagnostic only;
consumer drivers must restore them on failure and compare unchanged full
graphics afterward. These cuts do not qualify an optimization or justify
shipping lower quality.
