# Native particle passes

The unchanged battle bridge calls `Anim.drawParticles` in bands around its battler captures. The native binding borrows existing event and copied-background painters; it does not create particles, a script VM, a task scheduler or another frame clock.

`Gen3Battle.moveOamObjects` factors the native hardware ordering already used by `drawMoveOamObjects`. The default native painter retains its existing singles path and doubles fallback. The explicit source pass can classify all four real battlers into source bands, shares one ordering sample per guarded UI capture, and uses actual native priority, subpriority, live OAM Y and retained tie ranks. First exact key/Y ties retain the existing `global-sprite-slot-history` residual. Unknown direct OAM events use the existing native event-order/front-layer fallback; no priority is invented. This is not complete hardware sprite-slot parity.

The pass borrows native monbg copies before/within/after OBJ as appropriate, then native Surf/flourish extras with `skipEvents`, so OBJ are not drawn twice by that extra layer. Existing particle decorators retain their native event positions. Each draw is graphics-scoped; replaced admissions/clips, owner teardown and callback failures stop the borrowed pass without advancing or cancelling the native effect. The native OAM tie diagnostic is also classified as presentation in suspend witnesses.

The new ROM-free fixture compares the actual native singles painter trace against source bands over all five GBA admissions, checks separate captures at the same frame, query-only clocks/RNG/HP/queue, native particle decorators and failed-callback target restoration, changed cohorts, actual generic monbg copies, unknown-key fallback and all four real doubles slots. Local execution is pending because free space is below the20GiB project reserve; the installed safe maintenance helper found0 eligible bytes. No fixture pass, actual graphics fix, clean map/terrarium frame, physical-window result or FPS acceptance is claimed.

Earlier CPU probe `95cc3d63ee` reaches a real missing `Anim.drawParticles` call in the unchanged bridge. Actual battle probe `43b5eb8d59-firered` reaches the native command and stops earlier at missing `Ui.targetHidden`; its separately offered selection binding still needs actual graphics retesting. Tests and future graphics runs use isolated QA profiles and never player saves.

Contributions by Roxas2712. Existing native code, art and applicable third-party rights retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and credit requirements.

Public baseline note: this older public branch does not contain the fork-only SuspendJournal owner. Its one-line OAM diagnostic classification and semantic-witness fixture remain in the fork offer; no private/native Journal body is copied into this public PR.
