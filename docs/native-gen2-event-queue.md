# Gen2 presentation events in the native queue

`BattleState:push`, `pushAll` and `pushFront` admit Gen2 presentation events
to the controller's existing queue. Native `say`/`sayNext` producers use the
same public seam and the existing insertion cursor. No parallel queue,
typewriter, animation VM, HP clock or combat simulation is introduced.

Supported event kinds are `message`, `move`, `damage`, `heal`, `status`,
`text-pause`, `item`, `weather`, `stage`, `run`, `money` and `win-text`.
Optional cry, sound, sound-wait and move-animation fields use the existing
native services. Move lines finish without an extra A/B acknowledgement;
ordinary messages still wait for the native input path. Text finishes before
the event's animation/HP/sound wait, following the inspected split Gen2
screen contract. Explicit pauses use the native wait owner. A stuck sound
wait has a bounded native timeout and stops its actual sound.

Damage/heal event HP is a display snapshot, not an instruction to damage or
heal a Pokemon. A heal to45 followed by damage to15 can be displayed in order
even when the logic already owns15 HP. `Gen2HpPresentation` drives both beats
through the same admitted pixel step, without changing party HP, PP, status
or RNG. Queued status updates similarly change the native displayed status.
Its public view is rebuilt from native battlers after checkpoint restore;
the view's metatable is not serialized.

Malformed batches fail before partial admission. Unsupported semantic event
kinds are explicit errors, rather than a text-only fallback pretending to
switch a battler or finish a capture. Send/faint/identity/Transform display
transitions, experience/learning, catch and trainer/picker events still need
their own implementations. The source model's pure turn/constructor API and
complete event compatibility remain open.

Contract inspection: Gen1Recomp `535a5ec0` / current `e46d1eb2`,
`src/ui/gen2/BattleState.lua`. This change integrates the existing native
owners; source and third-party provenance in those owners remain applicable.
ROM-free tests use real SDK decorations, native queue input, the actual Gen2
VM, HP/status presentation and native sound service with a device-boundary
audio stub. They do not establish complete client, graphical or package
acceptance.
