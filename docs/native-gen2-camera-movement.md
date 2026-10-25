# Native Gen2 external movement handoffs

`src.world.gen2.FieldMoves` now resolves to `Gen2FieldMoves` for its movement
constants and `isBiking` / `isSurfing` predicates. They are the existing
`Gen2PlayerState` functions, so scripts and native surf/bicycle changes remain
immediately observable. There is no shadow movement byte. Legacy action,
fly-picker and collision-classification APIs are still absent: native script
and ROM-derived terrain protocols must not be replaced with guessed results.

This is sufficient for the supplied continuous camera controller to install
over the existing native `pollInput` and `stepBody` phases. Merely supplying
the name was insufficient for forced terrain: that controller completes its
public landing phases itself, then hands ice/current/forced-door movement back
to the engine. The native engine previously waited for its own grid landing
before starting those actions.

`resumeForcedMovement` now admits that return before ordinary input. Current
and forced-door collision bytes select their native direction without a held
key. The external ice `turningDirection` latch starts the existing ice handler.
Both paths retain native collision, actor interpolation, script queues and
completed-step callbacks. They do not replay an already completed free-body
landing. Blocked forced movement retains ownership of that frame. Scripts,
overlays, transitions, battles and in-progress actions cannot acquire a second
queue. The external ice latch and native ice latch are retired on map changes;
ordinary floor clears the external latch. Other generations retain their path.

## Verification

- `tests/engine/gen2_field_state_queries.lua`: 30 state/alias assertions.
- `tests/engine/gen2_forced_body_handoff.lua`: 584 assertions using real native
  maps, collision, runner and actor queues across Gold, Silver, Crystal and
  Prism, plus other-generation refusal. Includes blocked currents, directional
  walls, pending owners and error recovery.
- Existing body/input, special-handoff and CountStep suites: 21, 549 and 313
  assertions respectively.
- The committed fork passes 328 engine suites, three SDK suites and all quick
  tiers. The independent upstream composition passes the focused native suites.

An additional local CPU probe loads the supplied `3.1.2-omega.1.8`
`GoldCameraControls`, `FirstPerson`, `ThirdPerson`, `VoxelState` and `Mat4`
modules without changing their source. It passes 92 assertions on both the
fork and independent upstream composition. It exercises actual camera-space
key/stick math, both selected camera modes (including an extended third-person
body bearing), sub-cell travel, occupied-wall sliding, native counters, a real
coordinate script, Repel text ownership, native bicycle/surf movement and
ice/current/door returns. The previous `main` fails installation with
`Gold free-movement dependencies unavailable`.

The probe supplies a renderer-availability boundary and does not draw graphics.
It uses public native fixtures rather than an imported ROM. Script clocks
outside the body phase are not a complete game loop. This is **CPU integration
acceptance**, not full-package, GPU, all-story or Windows hardware acceptance.
No supplied mod code/assets or cartridge data are distributed. See the
[source-bound receipt](qa/native-foundation/johto-native-camera-state.json).
