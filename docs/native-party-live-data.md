# Live native party data

A wild battle usually has no battle-local playerParty. PartyMenu previously left
its public party field nil, while its native input and drawing separately fell
back to save.party. Presentation consumers reading the advertised party saw an
empty team even though the native picker could select the earned starter.

The constructor now resolves one actual party reference: an explicit selection,
then a battle-local selection, then save.party, then an empty list. It accepts
the native boolean battle flag without indexing a boolean. No party is copied,
inserted into a save, healed or reordered by this resolution.

Validation: 106 live-identity/native input/cancel/precedence checks across Red and
the five Gen2 editions, plus 111 battle PACK, 6,571 party navigation, 540 scoped
trainer-party and 1,615 item-dispatch checks pass. The new regression fails on
the preceding source. These are ROM-free source checks; full Gen2 party screen,
forced replacement, unchanged-client GPU and packaged-release acceptance remain
separate checks. The shared party controller is retained.

Gen2 queued interactive children now publish the native submenu phase before
their constructor runs. The same queue remains suspended through nested pickers
and resumes exactly once after the child releases the stack. Gen1/Gen3 retain
their existing phase. Another 84 input-owner checks pass. The Gen2 party boundary
also refreshes each actual Pokemon's catalog name while preserving its nickname,
so unchanged presentation consumers need no fabricated name or copied Pokemon.
