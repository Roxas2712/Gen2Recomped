# Ball cells and opening effects share one native timeline

A source renderer draws its fitted ball through its own imported cell, then
calls `ball_open.draw()` for opening effects. That call formerly borrowed the
complete native painter, adding another ball at native coordinates and size.
Real FireRed capture `b3d97aa123` shows both balls simultaneously after native
send-out admission was repaired.

Keep the existing native painter as one implementation with two paint modes.
Ordinary native battle drawing retains the complete layer. A source opening
pass uses the effects component, including the same native particles, shiny
sparkles and capture stars, without adding another ball cell. Base calls inside
an actual native whole-layer boundary still borrow that complete layer once.
The source's fitted position/scale and the native clocks, queues and capture
math are untouched. No private renderer/controller body is included.

Validation:

- Focused run `4b62b07721`:11 groups pass. The new real-painter fixture passes
  235 assertions across five GBA editions and player/opponent/capture modes.
  It checks effect command equality, native complete-layer preservation,
  once-only wrapper borrowing, no artless duplicate, and read-only painting.
- Exact predecessor `e8d494e1`, run `2826493842`, reproduces45 failures with
  the identical fixture and no native controller overlay (205/250 checks;
  the old extra draw also adds data-dependent assertions). Corrected code
  passes235/235.
- Current fork main `c548cd16` composition `d3dc3867ae`:181 CPU groups pass.
  The subsequently fetched main `0af0b3cf` was integrated as `23fcddaa`;
  frozen composition `53b81840c4` also passes181 groups. Four additional
  new-main appearance/new-game/ending groups pass separately.
- Older-public composition `696b620eea`:69 groups pass, including235 new
  assertions. It retains older native simulation bodies and previously
  offered cartridge/art/stage prerequisites. The offered raw branch reuses
  the existing ball painter boundary from the public presentation component
  (unchanged preimage of #329), then applies only the component split.

A fresh rendered FireRed/LeafGreen flight comparison is still pending and must
check both actual fitted draw rows and zero raw native ball cells. CPU command
checks alone are not complete visual flight, trainer-pose or FPS acceptance.
The earlier capture and failed QA probes remain preserved. Hosted CI is
separate. Only owned profiles/copies are used with the20GiB free-space floor;
private files and player saves/profiles are untouched.
