# Separate rain costs from planar reflection costs

Unchanged consumer bddb51819c, native FireRed Cerulean City, High quality,
1024x768, Metal/LOVE12 on Apple M3. Engine source 9f8cc0fb includes freshly
fetched main cbb552a8 and the qualified shader corrections. The later static
palette projection cache is absent from this measurement.

Each row uses 90 settling ticks and 120 measured frames. Every recorded frame
has a distinct consecutive renderer tick. Stop the Lua sampler before the
series; no draw spy, GPU readback or file writing occurs in a measured window.
Use the same bank position and camera parameters for all weather combinations.
Accelerate only QA puddle fill/drying to .25/1 seconds (defaults 45/150),
requiring exactly dry or fully wet surfaces before sampling. Quality, rain
particles, geometry, map rules and the private package remain unchanged.

| Camera | Weather | Scene reflections | Mean ms | Draw ms | Update ms |
| --- | --- | --- | ---: | ---: | ---: |
| Normal | Clear | Off | 20.233 | 13.370 | 3.639 |
| Normal | Clear | On | 18.926 | 12.308 | 2.927 |
| Normal | Rain | Off | 17.628 | 10.895 | 2.618 |
| Normal | Rain | On | 20.366 | 14.835 | 3.552 |
| Normal | Clear, repeat | Off | 20.031 | 13.857 | 3.435 |
| Third-person | Clear | Off | 25.084 | 18.152 | 3.510 |
| Third-person | Clear | On | 30.691 | 25.082 | 3.704 |
| Third-person | Rain | Off | 23.491 | 17.072 | 2.870 |
| Third-person | Rain | On | 56.989 | 51.019 | 4.504 |
| Third-person | Clear, repeat | Off | 21.836 | 16.266 | 2.425 |

Compiler counts/time remain constant inside every measured row. Rain renders
1810 quads in Normal, 2330 in Third-person, with or without scene reflections.
Wet scene reflections use four visible heights in Normal and nine in
Third-person. Native map cells/collision/elevation/warps remain byte-equivalent.
Only owned QA identities are used; no player saves are read or changed.

At this location the large warm-frame regression is the combination of rain
with multiple reflection heights, rather than rain particles alone. Dry
Third-person also misses 60 FPS, and the repeated dry controls vary by about
3.25 ms; do not generalize these samples to every map or cold transition.

A separate rejected experiment coalesced inactive derivative uniforms after
qualified native ownership observation. Its 132 Metal checks pass, but the
same wet Third-person view measures 72.832 ms warm, versus the qualified
56.532 ms earlier baseline. It is excluded from the current engine offer.
An instrumented diagnostic outside its timing windows counts 5441 mirror draw
submissions per frame, including 495 actor submissions across nine heights.
Those instrumented CPU submission spans are not GPU execution timings.

Receipts: matrix 9de31f8fc7 (CPU/source 8ba80100ee), rejected experiment
b9fbe3ad7a (source b0e875074c), native contract 1df1c89490.
60 FPS, cold transitions and full OS-window acceptance remain open.

Contributions by Roxas2712 under LICENSE-ROXAS2712.md; existing rights remain.
