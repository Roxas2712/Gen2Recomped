# Native Gen2 queue screen state

Gen1Recomp's native Gen2 battle screen publishes `resolving` while its
queue executes and exposes the current text through `message` and
`messageTimer`. The shared controller previously published `messages`
and kept that text only in `current.text`. Readers of the native Gen2
screen could miss both the resolution state and its message.

`BattleQueuePhase` selects the edition's real phase at the existing native
writers. Gen2 uses `resolving`; other editions keep `messages`. Older Gen2
`messages` queues remain readable and normalize at the actual queue update.
This does not rewrite the phase around a renderer or introduce another
battle controller.

The native text-start path publishes the same current source text. Its
48-frame public hold value follows the Gen2 screen convention, which waits
for A/B rather than timing out. The existing typewriter and prompt delays
still own every glyph and input. The same acknowledgment/choice completion
retires the hold. The existing decision boundary clears the text. Native
LinkBattle completion also releases it before exposing its next decision.

Classic and widescreen text, detached snapshots, link resolution and
operator replay/resume recognize the same queue predicate. Other editions'
text fields and phase meanings remain unchanged. Decision checkpoints allow
the additional native message fields; active queues remain unsupported as
semantic decision checkpoints.

## Validation and limits

`tests/engine/gen2_battle_queue_view.lua` exercises actual FIGHT/refusal input,
typing versus manual advance, non-expiring text holds, classic/wide draw
ownership, legacy queued children and native YES/NO completion. It covers
Gold, Silver, Crystal, Prism and Polished Crystal, with Red, FireRed and
Emerald regressions. Existing checkpoint, action, snapshot, PACK, scene,
item and real-loopback replay suites cover their native owners separately.

The native contract reference is Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`,
`src/ui/gen2/BattleState.lua`, including `advanceQueue`, `syncTyper` and its
manual prompt loop. Existing project rights and notices remain applicable;
see `NOTICE.md`. No game data or client/mod files are included.

This corrects a source-confirmed screen API gap. It does not establish that
this gap alone caused the observed white battle view after medicine. That
failure still needs a new unchanged-client GPU observation, including the
staged scene receipt during the queued message. Full native page-layout,
party-result timing, event-kind and animation API parity remain separate
qualification requirements. No release or whole-mod acceptance is claimed.
