# Native Ruby and Sapphire options

RS already imports its original option labels, value positions, palette and
window metadata as part of the party/menu manifest. The generic options screen
looked for another edition's vocabulary, so the six cartridge options were
absent and only additional engine settings appeared.

The byte-exact RS options controller/rendering from Gen1Recomp
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b` now consumes those existing ROM
resources in an isolated reference context. The individually hashed source
retains its existing GPLv3/additional terms and is listed in provenance.
No generated images, labels or cartridges are included.

`Gen3RsOptionValues` translates the original zero-based choices into the
existing host fields: numeric text delays, `battleAnim`, `battleStyle`,
`stereo`, `gen3ButtonMode` and `gen3Frame`. The six pending native choices
commit on close through the host option writer. Sound preview remains local
until that commit. The original native frames, selected-value colors,
row highlight, scrolling, wrapping and twenty frame types are retained.

The host's additional option rows remain reachable through MORE OPTIONS.
Their existing value, step and activation callbacks receive the actual host
game. A changed host extra persists without committing the six pending
cartridge values early. Existing mod/controls screens and the owner's close
callback remain hosted. Other editions retain their own options views.

## Verification

The focused suites pass 186 assertions: 148 enum/host-field/false-value/frame
round trips and 38 vocabulary/resource/edition-isolation checks.

Both native prepared fixtures pass on runtime
`61b5732363948a09cfb2ffc5ed379a530ff14961` after fresh full imports. Their
extended host-callback fixtures also pass on
`3780c80e8a18139858c46229685767975bb11a16`, whose only further change is
test coverage. Each extended edition run records twelve final-renderer
captures and checks eight cases:

- All six option enums wrap left/right, including all twenty frames.
- Pending native values remain unchanged in the host until close.
- Existing host extra rows remain reachable.
- Host step/activation callbacks run with the real game and persist correctly.
- Native CANCEL commits and persists all six settings.
- The owner's callback runs exactly once.
- Reopening uses the saved frame and UP wraps to CANCEL.
- Actual main-menu OPTION/B return restores the original menu.

Integration `1f00e0eed5c4dd625d8c8795e5bdc7c2c3501053` preserves public main
`a8833b354413996e07ff2cdff73b94c656df54bc`, including its newer ball/sendout
presentation. Both editions pass fresh full imports and the same complete
twelve-capture option fixture on that integrated source. Five focused
integrated suites pass 613 assertions, including native ending save, Hall of
Fame and credits contracts. The subsequent head changes documentation only.

Draw-time save bytes and gameplay RNG remain unchanged. The initial native
run exposed an update continuing after its owner was popped during fade-out;
the final runtime stops that update safely. The final head adds documentation
only. These are prepared UI fixtures, separate from ordinary story coverage.
