# Native Gen2 move-selection screen contract

When FIGHT entered the shared controller's `moveSelect` phase, clients written
against the native Gen2 screen's `moves` phase could paint the scene and HUD
but no move cards. The native screen also lacked `playerMoves()`.

Gen2 now enters `moves` through the same native command dispatcher and queue.
`playerMoves()` returns the current chooser's actual move instances, including
temporary movesets, rather than copying the persistent party list. There is
no alternate controller, presentation-time phase rewrite, or client-specific
patch. Other generations retain `moveSelect`.

The common selector predicate admits the earlier `moveSelect` spelling for
existing Gen2 continuations. Input, cancel, public command admission, snapshots,
classic/wide/native translated drawing and portable continuation validation
share that predicate. The queue's private `afterQueue` token remains stable.

ROM-free regression coverage exercises actual FIGHT input, native move-list ink,
cursor navigation, cancellation without PP/damage, reopening, actual turn/PP
resolution, current native moveset identity and older phase continuations.
Separate existing suites cover public action/snapshot routing, grid controls,
bottom UI ownership, GBA refusal returns, battle reconstruction and suspend.
These fixtures do not establish full client, GPU, Windows or release acceptance.
