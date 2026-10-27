# Native GBA faint friendship

Contributions by Roxas2712. Existing licences and notices remain intact.

The reached native faint command updates friendship before publishing
`battle.fainted`. Mods receive `happiness.changed` with the native event byte,
the actual before/after values and `reason = "event"`. Both stored aliases,
`friendship` and `happiness`, are synchronized. Zero friendship produces no
spurious change event. Eggs are excluded, including the alternate `egg` marker.

FireRed, LeafGreen and Emerald compare against the highest-level present
opposing working controller. An already announced KO still has a controller;
an alive-only targeting query would incorrectly lose the level of a Destiny
Bond user. Ordinary faints lose one point. A level gap above29 loses five
points below friendship200 and ten at or above200. Positive item, ball and
birthplace bonuses do not apply to these negative changes.

Ruby and Sapphire instead use the actual script attacker/target registers.
They do not adjust friendship when the other selected level is equal or lower.
Their residual HP commands capture the levels selected by that phase, before
a subsequent phase can replace the registers. Weather, per-battler status,
Leech Seed/Liquid Ooze, delayed attacks, Perish Song and portable field-residual
batches set those registers through their native owners. The first present
controller can be a partner in doubles; it must not be replaced by a presumed
enemy. Script announcements use their reached script context, including
public damage-hook changes and native called moves.

The command is idempotent for the active controller. A genuine native heal
clears logical death without inventing a new controller. A switch builds a
new controller. Friendship processing shares the faint announcement guard,
so a callback cannot publish a checkpoint halfway through that command.

Linked simulations update their detached remote party copies as well as the
local copy, keeping subsequent friendship-dependent damage and state hashes
consistent. Only the local party owns public friendship notifications. The
saved world party is unchanged. This copy-replication behavior is additionally
tested with actual Gen2Recomped loopback peers; it is not established by the
single-engine reference comparison alone.

Checkpoints preserve the phase registers, captured residual levels and the
optional per-controller command marker. Restore rejects invalid slot IDs,
phase labels, non-byte levels and non-boolean markers before publishing state.
The serialization fixture prepares a semantic state; it does not establish
ordinary gameplay save acceptance. These fields participate in the fatal
active-state link hash with canonical controller IDs.
The party hash also includes effective native friendship independently of
`happiness`: a raw alias-only edit must not pass a turn hash unnoticed.

Native battle command revision is **26**, fixture digest `adb591544e735888`.
The independent Python integer FNV calculation over the captured revision24
surface reproduces24 (`2882b526b6881e0a`),25 (`35f797dbee5a94af`) and predicts26
by replacing only the command revision tag. The current runtime checks the
predicted26 digest. Older generations retain `e33d251961f2a41d`; party codec1
and callback ABI1 are unchanged. Mixed command revisions cannot start lockstep.

`tools/gen3_faint_friendship_contract.py` compares53 authored scenarios in all
five GBA editions, singles, right-side doubles and an absent opposing left
slot:795 paired cases. Actual native actions and residual schedulers execute
on both engines. The comparison includes HP, friendship aliases, public event
order and every raw RNG call. Metronome uses a deliberately authored one-entry
Explosion pool; default cartridge move selection is not claimed. Use
`--disable-native-owner` as a negative control: disabling only the Gen2
friendship command must produce reference differences.

The read-only reference is `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
R/S BattleResults accounting/publication, other remaining native move and AI
families, unchanged original-mod acceptance and complete gameplay testing
remain separate work. No global battle-readiness capability is enabled.
