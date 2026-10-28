# Native GSC status presentation

The native shared controller selected Gen1 SLP/CONF animation names for GSC.
Those programs do not exist in the GSC catalog. It also recognized a status by
English substrings in already-translated text, dropping the animation under a
translation or inventing one for unrelated text containing the same words.

GSC sleep now selects ANIM_SLP; confusion selects ANIM_CONFUSED. Player sleep
runs before its caption, enemy sleep and both confusion sides after theirs.
The actual imported misc-ID table admits those rows even when ordinary move
animations are off, through the real public animForId entry point. Actual move
rows retain their existing option gate. Ball metadata retains its own path.

The native status decision reports optional presentation metadata in its fifth
return value: kind, exact message index and actual blocking status. Its first
four decision/message/self-hit/reason values keep their native ABI. Registered
Gen1-style handlers with an explicit kind in slot four are recognized while
retaining that value. The original caption is preserved. A later paralysis
line cannot replace the earlier confusion caption, and arbitrary English words
cannot create a status animation.

The same structured blocker fixes localized full-paralysis cleanup: the
actual PAR handler, rather than the words in its message, owns the existing
native volatile cancellation. Counter order, damage arithmetic and random
rolls stay at their existing owners. The existing GBA Snore implementation
supplies explicit sleep metadata so its previously displayed caption/effect
survives this change; no Gen3 implementation is imported into older upstream
source trees lacking it.

## Sources

The explicit event-kind/index approach is compared with Gen1Recomp's frozen
535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91 src/battle/Status.lua and the shared
BattleState:sayStatusMsg boundary. The real GSC program names and side-specific
ordering are independently checked in [Crystal effect_commands.asm](https://github.com/pret/pokecrystal/blob/5c877ef55197039c9676e8e3eec6d254b1c40fe8/engine/battle/effect_commands.asm).
Pinned source blob: 0100aadbd8d8efe2495422d3209c9ffe9068533e. Relevant lines:
player sleep160/178, player confusion256/260, enemy sleep387/391 and enemy
confusion484/489. Existing Gen1Recomp/Cedric licences and credits remain intact;
see compat/gen1-gsc/ and LICENSE-ROXAS2712.md.

## Verification and limits

gen2_status_presentation drives the real native statusInterrupt, queue, public
misc admission and command VM for Gold/Silver/Crystal, both sides, old flat and
original source-native animation schemas, English/German captions and the
scene-off option. It covers late paralysis, actual confusion damage, exact
message ownership, explicit registered metadata, misleading text, wake/snap/
flinch/skip/missing-program paths, PP/random draw preservation and non-GSC
animation identities. Existing GBA Sleep Talk/Disable/link/secondary suites
provide shared-controller regression coverage.

A separate local original-Crystal-ROM run uses ROM-free battlers with actual
ROM program data. Eight native sleep/confusion cases (both sides, both
languages, ordinary move animations off) match the frozen reference's complete
command/object/OAM/BG state. The actual programs take198/98 VM frames; each
passes the public entry point once and adds no battle random draw beyond the
native confusion decision. Existing full428-program/ID comparison,2804 cases/
355718 VM steps, picture data and native Fly/Dig checks still pass.

This qualifies the described engine CPU/ROM-data paths. No new GPU, audible
output, unchanged-VASC visual, OS-window, Windows, performance or packaged
release acceptance is claimed. This change does not overhaul GSC's remaining
native sleep/recharge/turn rules; their separate gameplay audit remains open.
No mod, original ROM or player profile is changed, and no ROM bytes/art are
committed.
