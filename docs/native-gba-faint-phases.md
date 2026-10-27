# Native GBA faint phases and zero-effect chance commands

Contributions by Roxas2712. Existing licences and notices remain intact.

Mods observe native `battle.damage_dealt` and `battle.fainted` producers. The
order of these notifications, the major status visible at a faint, and the PP
slot used by a reaction are part of the runtime contract.

## Explosion and healing

Every reached native Explosion body sets the user's HP to zero before its
calculation. The field-wide Damp gate runs once. All-other-battler scripts
visit present controller slots, including a KO whose controller has not yet
removed it. Each reached recipient keeps its own accuracy/calculation command.

The recipient announces its faint before the user. In doubles the user's
announcement waits until every recipient body has finished, including miss,
protection and immunity paths. Actual native callers use the same ownership;
the caller completes its child target loop before releasing the user faint.
The old generic Explosion callback cannot repeat the prefix's HP write.

Logical fainting is distinct from the queued visual slide. A mod's raw HP write
does not undo the logical command. A genuine native heal does: for example, a
Shell Bell can restore HP during a deferred spread body after a damage hook
writes positive HP. A later body still executes its own set-HP command. The
shared corpus tests this observable distinction rather than treating all
positive HP as either a revival or a permanent self-KO.

## Announcement and reactions

GBA announcements clamp HP and clear major status, sleep turns and the toxic
counter before publishing the detached faint notification. The target's
announcement precedes Destiny Bond and Grudge. Destiny Bond requires the
current move's actual opposing attacker. Grudge requires a still-living user
and the current native selected PP index; it drains that index even when the
called move has another identity. Ordinary unowned calls have no selected
index. Nature Power retains its borrowed selection across later target bodies.
Destiny Bond resolves first, so its fainted user cannot subsequently lose PP
to Grudge. The native move canceller clears the acting user's old reaction
flags, while a victim's flags are not eagerly erased by its announcement.

Residual and self faints cannot infer a killer from a convenient fallback foe.
Earlier generations retain their existing reactive order. Complete authored
calculation records retain their existing pre-hit ownership; this does not
qualify every possible custom effect-record phase.

## Native chance and state boundaries

Ruby/Sapphire execute a selected effect-chance opcode even with effect byte
zero. Its `0..99` draw occurs after reached HP damage and before faint checks.
`Gen3ZeroChance` owns the statically zero-payload families and their admission
sites, including relevant multi-hit endings and immunity paths. It reads the
live battle RNG, never invents another damage calculation, and is not a general
replacement for nonzero or dynamically replaced secondary-effect descriptors.
Explosion has no such opcode. The existing calculation contract now requires
every raw RNG call to match; its former R/S trailing-draw exception is removed.

This component introduced native battle revision **25**, with independently calculated fixture digest
`35f797dbee5a94af`. Revision24 was `2882b526b6881e0a`. Older generations keep
`e33d251961f2a41d`; native party codec1 and callback-record ABI1 remain distinct.
Mixed GBA command revisions cannot enter lockstep. The subsequent [native faint friendship owner](native-gba-faint-friendship.md) advances the current revision to26.

Logical faint, Grudge and Destiny Bond participate in the fatal active-state
link hash. Checkpoints preserve the optional logical marker and reject a
non-boolean marker before publishing state. An announcement in progress is
not a resumable decision point. Script errors retire move/action/release
owners without undoing HP commands already executed.

## Qualification scope

`tools/gen3_faint_phases_contract.py` compares 930 paired cases across all five
GBA editions, singles, right-hand doubles and an absent opposing left slot.
Both engines execute native actions and the same public damage/faint consumers.
The corpus includes status, protection, Damp, immunity, present dead slots,
raw HP writes, real Shell Bell healing, native Metronome calls and the native
Sand Nature Power selection. The Metronome pool is deliberately authored with
one allowed move; default cartridge selection is not established by this test.
HP/status/PP snapshots, notification order, calculation observations and the
complete raw RNG stream must all match without normalization of missing calls.

Engine tests additionally exercise real loopback peers, isolated active-hash
divergences with identical HP/PP/party state, strict checkpoint preflight, cold
semantic-state restoration and native error cleanup. The checkpoint fixture
prepares a logical-death state; it is not an ordinary gameplay save claim.

Example comparison:

```sh
python3 tools/gen3_faint_phases_contract.py \
  --reference-root /path/to/read-only/Gen1Recomp \
  --lua /path/to/luajit --output /new/qualification/output
```

The read-only reference is `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
Faint friendship is covered by the [subsequent native owner](native-gba-faint-friendship.md).
Result-policy faint bookkeeping, broader contact/per-hit scheduling,
nonzero/dynamic R/S chance payloads, other native move families and complete
unchanged-mod/gameplay acceptance remain separate work. No global battle or
presentation readiness capability is enabled by this component.
