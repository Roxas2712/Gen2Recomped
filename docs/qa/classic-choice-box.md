# Classic choice-box defaults

The global YES/NO box had inherited FireRed dimensions. Restore the classic `(14,7,6,5)` tile rectangle while retaining the expanded `(13,7,7,6)` furniture for native GBA/DS/later caches. Authored themes still merge afterward; the public choiceBox table keeps its identity.

The native Game and final render pipeline were exercised on English Red in pinned Gen1 reference 535a5ec, baseline 8f19066d, and the candidate. Each uses a fresh import of the same owned ROM and an identical controlled backdrop. Full 640×576 output at verified scale 4 was compared without cropping or recolouring. Baseline differed by 9,568 pixels with YES selected and 9,632 with NO; the candidate differs by zero pixels and zero byte values in both views.

All three hosts also passed real Down/A/B input, exactly-once callbacks, return to the underlying state, draw-time save immutability and unchanged saved options. Screenshots were visually inspected and retained in private QA output; no generated game assets are committed. This is focused choice-widget evidence, not whole-world or translated-screen parity. Native GBA/DS/later dimensions are covered by the unit checks, not by a visual claim.

All 24 focused assertions and 119 stable-source compatibility runs passed, including the native engine suites, matrix, gallery/hooks, API3 and unchanged external fixtures. See the two JSON reports.
