# Visible trade sprite exclusion

The native trade BG draws two images of its 256px ring. An offscreen duplicate overwrote the visible true-color picture's palette exclusion rectangle. Only a picture intersecting the 160x144 viewport may now update that rectangle. Sprite placement and animation remain native.

Validation: 27 assertions cover centered, left-clipped, right-clipped, wrapped and fully offscreen positions, plus indexed art. All native suites, the switch matrix, pinned-reference API3 and external mod fixtures passed: 121 stable-source runs. No performance claim is made.
