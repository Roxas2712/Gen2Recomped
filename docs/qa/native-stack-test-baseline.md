# Native stack test baseline

The exact viewport prerequisite `ce4a825a961d35df2e6748b22632843f77d5c671`
passes 100/110 engine suites and 3/3 SDK suites under the official
`scripts/test.sh` command. The offered studio source `c23c6627` passes
117/127 engine suites and 3/3 SDK suites. Both runs fail the same ten named
suites, before and after the runtime/hotbar/studio additions. Both runs omit
the ROM-dependent content/link tier when no generated Red dataset is present.

The repairs retain the actual production owners:

- `rebind_capture_bug510` and `rebind_swap_clear_bug589` locate rows by their
  public action metadata, retaining release-to-commit, swap/clear/cancel and
  uniqueness assertions across the native twelve-action map.
- `soft_reset_bug563` and `tool_mod_hooks` use actual `Game` method lookup,
  including the profiling `_step` body, instead of incomplete plain tables.
- `quit_thread_shutdown` executes the real `love.run` function to prove veto,
  Android-only exit and return ordering. A pattern stopping at the first
  nested `end` could not establish any of those behaviors. Existing native
  shutdown assertions remain appropriate to this older host.
- `update_check_tests` and `update_tests` use this engine's actual
  `Gen2Recomped` payload names and upstream release URL. A negative case
  explicitly rejects a foreign Gen1 payload; the updater is not changed.
- `wide_battle_layout` tests the authored OAM anchor positions, interpolation,
  wobble, empty frames and bounded overshoot, rather than expecting two
  unrelated frames to coincide with anchors they do not occupy.
- `gate_meta_coverage` gains real public-API/owner tests for Birch enter/finish,
  bulk block replacement, world ticks, egg hatch completion and native HUD
  ownership. No coverage debt is added to silence the gate.
- `gate_fingerprint` retains mutation/determinism checks and uses the
  independently reviewed `41e69caf4afa35ab` fixture pin from the prior native
  registry audit, with per-section pins and four Sinnoh-registration removal
  checks. No serializer, registry, hash algorithm or ROM golden is altered.
  See `tests/goldens/fixture_fingerprint.md` for the audited input change.

The changed stack still needs its own exact-source full test result. A passing
test-fixture repair is not complete Gen1 behavioral parity, unchanged-mod
gameplay, current upstream-main integration or packaged-release acceptance.
