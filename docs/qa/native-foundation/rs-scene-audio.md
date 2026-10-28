# Native RS scene cry completion

The native RS new-game scene must ask the existing Sound owner whether a cry has
completed. A physical output source can continue to report playback after the
native recording duration, especially when an output device is suspended. The
scene bridge previously waited on that source directly and could strand Birch's
`WaitForAzurillCry` phase.

The bridge now delegates to `Sound.isCryFinished()`. It keeps the source returned
by `Sound.playCry`, species admission and all native clock/device/replacement
policies. Queries do not tick, stop or replay audio. No separate scene timer,
private mod change or save migration is introduced.

## Qualification

- Failed unchanged-mod Ruby diagnostic `b158fcdea4`: the native scene remains in
  `WaitForAzurillCry` at timer16384; its source reports playing while the native
  clock62434 exceeds untilFrame1033 and `finished` is true. The machine was
  screen-locked; this is not a visible desktop acceptance run.
- Frozen public-fork source `f2a6e05e84`, incorporating main `e99db064`, passes all
  113 selected CPU groups. The dedicated scene test passes239 checks for Ruby
  and Sapphire: idle, whole native duration, repeated pure queries, a still
  playing device, early source completion, unavailable device, no recording
  pack, replacement ownership, invalid species and Gen2 admission exclusion.
- Existing native cry script waits, RS cache/boot contracts, public event seams,
  field/arrival contracts and the newly merged Gen2 faint/background/object/
  picture owners pass in that same frozen source.
- The initial combined run `9926a0a4c2` retained50 failed party-summary trace
  comparisons. The updated headless quad stub had put distinct function values
  on each equivalent quad. Shared metatable methods retain mutable viewports
  and the comparison of actual drawing arguments; no renderer assertion was
  removed. The successful113-group run includes that correction.

Real unchanged-mod flight/profile qualification follows separately. No complete
RS story, visible desktop, all-map or sixty-FPS acceptance is claimed here.
