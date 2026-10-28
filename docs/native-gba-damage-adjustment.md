# Native GBA calculation and damage-adjustment ownership

Contributions by Roxas2712. Existing licences and notices remain intact.

Native GBA scripts have separate calculation, adjustment and accuracy commands.
Imported numeric move IDs must reach those commands in the selected edition's
order. A public damage hook can observe that ordering and change its result;
using a generic final random multiplier changes both mods and linked battles.

`Gen3DamageAdjustment` scopes native calculation options to the actual command.
R/S exposes a deferred calculation, then draws `0..15` and applies `100-roll`
at a reached normal adjustment opcode, including a draw for zero damage.
Set-damage sites skip that variance. The prepared calculation snapshots the
current RNG before the public hook; later commands read the live battle RNG.
Explicit authored calculation generators remain authoritative.

The adjustment site belongs to the native effect byte. Super Fang has no R/S
adjustment command; Endeavor checks failure before Protect and uses a set site
only when nonimmune. The fixed-damage family uses set sites, ordinary multi-hit
and Fury Cutter use nonimmune normal sites, and ordinary attacks use normal.
Confusion uses normal2, which cannot inherit False Swipe. Substitute prevents
False Swipe, Endure and Focus Band from capping the recipient's HP damage.

R/S retains every successful Focus Band proc for that target and move,
including a nonlethal earlier strike. Later reached commands still read the
current item and perform their own eligible roll. A later failed roll or item
removal does not erase the earlier proc. The existing individual-hit helper
keeps its old return semantics for other callers; the R/S owner requests its
raw proc explicitly. Adjustment metadata prevents a second roll at HP loss.

Explosion checks field-wide Damp once per direct/called move, writes the
user's HP before calculation, and calculates/adjusts before accuracy and
protection. Each reached spread target retains its own calculation. A failed
Damp gate stops the remaining targets. FR/LG/E retain their special branch's
post-accuracy Levitate/type check without adding an ordinary Wonder Guard
command. Explicit custom calculation records retain their own pre-hit owner.

Jump Kick's miss/protection branch silently calculates crash damage, with no
public move-damage callback, then applies its native halve/minimum/target-HP
cap. R/S first adjusts against the intended recipient. The resulting self HP
loss bypasses the user's Substitute, Endure and Band. Confusion also uses a
silent base calculation followed by its edition's self-hit adjustment.

Delegated amount-only public hooks retain the calculation's metadata. Complete
hooks can return an amount without calling `next`; the engine supplies the
native default flags and infers the category from the move, without inventing
a hidden calculation or RNG calls. Native amounts use `max(0,floor(tonumber
or 0))`. Adjustment works on its own metadata copy. Shared classic records and
imported move rows are not rewritten; earlier-generation owners remain intact.

Native battle revision is **26** after the [faint friendship owner](native-gba-faint-friendship.md). The independent fixture digest is
`ed48736806f1e02c` for FR/LG/R/S and `524ff88d849b1641` for Emerald after
retaining main's edition-specific secondary-command suffix. The earlier
integration without that suffix used `adb591544e735888`; revision24 used
`2882b526b6881e0a`. Mixed native battle
revisions cannot enter lockstep. The legacy digest remains
`e33d251961f2a41d` and native party codec remains1. Temporary calculation,
Explosion and proc owners retire before a menu checkpoint; they are not saved
as active controllers. The logical faint marker is separate persistent state;
see [native faint phases](native-gba-faint-phases.md).

## Qualification and remaining work

`tools/gen3_damage_adjustment_contract.py` executes the same authored,
imported-shaped move records against a clean read-only Gen1 checkout and this
engine. Each worker runs624 ordinary action cases (13 moves,24 state profiles,
two draw policies) and24 actual all-other-battlers Explosion cases. The default
matrix has five editions, singles/right doubles/absent flank, and delegated,
amount-only, RNG-replacement and complete-override hooks:120 workers and38,880
paired cases. These are fixture actions, not complete ROM-import acceptance.

The comparison includes HP, Substitute, PP, calculation values and RNG
boundaries, and actual damage events. Critical/effectiveness spellings are
projected into common numeric units; identity of every returned metadata field
is not established. Raw RNG streams remain in the logs and report. Every draw
and every observed boundary must match, including the selected R/S zero-effect
chance command. Missing trailing draws are no longer admitted. `passed` and
`full_rng_equal` describe this fixture component, rather than every move family.

Engine regressions also exercise captured public effect delegation, complete
overrides, metadata ownership, genuine Metronome-called Explosion, native menu
rounds, public cold checkpoint/continuation and actual host/guest link peers.
The authored one-entry Metronome pool exercises the caller's target/PP owner;
it is not a qualification of native Metronome selection.

Nonzero/dynamic R/S chance descriptors and broader per-hit held-item scheduling
still need further native qualification. Counter/Mirror Coat memory/routing, delayed
damage, Weather Ball/Hidden Power, default AI policy, remaining result schemas
and original-mod/gameplay acceptance remain separate work. Recognizing an
adjustment-site effect ID does not qualify that effect's entire implementation.
This change does not enable global GBA readiness or claim universal mod or
whole-game compatibility.

The qualified reference is `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
Public battler records and Explosion faint phases have separate owners and
regressions in [API3 battler records](api3-battler-records.md) and
[native faint phases](native-gba-faint-phases.md). Matching damage events alone
does not qualify every public battle boundary. Native calculation
failure metadata is interpreted only by the relevant GBA hit body, preserving
older-generation hook ownership and Explosion's special branch.
