# Native animation frame slices

The decoder retains the immutable 32-byte slices of the currently selected
frame for each animation row. It reads live metadata and compares the complete
new override table with the previous table on every call. Tile placement,
overlap order, cadence, dirty-cache invalidation and caller-owned old override
tables keep their existing behavior. `reuseAnimationSlices=false` selects the
original substring loop and releases the slice cache.

This is independent of palette projection reuse. It neither changes the
native clock nor skips animation updates, texture uploads or map observers.
There is no frame-global validity cache or additional retained frame history.

## Evidence

- Offered upstream component plus its declared palette prerequisite c08f8011:
  source syntax and 64,850 checks pass (receipt 78c85dc88e), including 61,140
  independent animation mutation/cadence/ownership checks.
- Isolated native LuaJIT OFF/ON/ON/OFF CPU test, 24,000 updates per leg:
  33.348 / 28.030 / 27.527 / 32.523 ms; all checksums match (7846b99efb).
  Mean CPU work for that operation falls by about 16%. This is not game FPS.
- Latest public main 43abf33d composed with these atlas changes at 6a043702:
  source syntax and 66,349 checks across 16 groups pass (23acc67266), including
  526 resource lifecycle checks, independent pixels and the existing shader,
  options and Hall contracts. The PR branch's runtime, assets, compatibility,
  tests and tools are byte-identical to that validated composition.
- Native Metal / Apple M3, fresh disposable field session directly in
  Cerulean rain, High Third Person, 1024x768: four full-scene captures pass all
  three exact comparisons (0e0a51dfb2). The test independently toggles
  an optional consumer reflection shader; animation slice reuse is enabled
  in all four images. This establishes current-scene compatibility, not an
  isolated native speedup from the slice cache.

That native run records 66.529 / 69.761 / 78.293 / 62.711 ms per frame for the
separate reflection shader OFF/ON/ON/OFF comparison. Named background activity
averages 47.56% and peaks at 186.7%, so these are unqualified diagnostics. The
optional reflection shader remains inactive in normal play. The nine-height
reflection blocker and stable 60 FPS remain open; the atlas microbenchmark
does not establish their cause or resolution. All 120-frame legs advance 119
native tick intervals, with no shader compilation during the timing windows.

The native host reports `nativeIntroSkippedForReflectionQA=true` and zero
intro boot frames. It calls the native new-game lifecycle directly into its
owned field fixture; no existing player save is loaded or copied. Managed
cleanup finishes after the native child exits, preserving logs and receipts.
The configured 20-GiB free reserve remains active.
