# Optional Gen1 peer adapter

Contributions by Roxas2712. This directory is a portable client for the same
explicit `gen1-session-v1` relay profile as the fork's additional cable UI.
Copy the directory to `compat/gen1_session` in the pinned Gen1Recomp checkout
(`2aec7650cb01845a4e98f1dbcf8a5c652990d984`). It uses that engine's own unmodified
`src.battle.g3u` modules; it does not import Gen2 game/save services.

```lua
local Peer = require('compat.gen1_session.Peer')
local seatJournal = Peer.credentials(profileFilesystem, stableProfileIdentity)
local peer = assert(Peer.new {
  journal = seatJournal, address = '192.168.1.10:7780',
  room = optionalExistingCode, -- omit to host; keep the journal to resume
  data = normalizedImportedDataset, -- source xgen Datasets shape, host only
  records = canonicalBattleParty,   -- source g3u Wire.record shape, 1..6
  generation = 1,
  onEvents = function(events) -- route to the peer's owned presenter
    presenter:enqueue(events)
  end,
})
-- Each frame: peer:update(dt)
-- Legal choices: peer.core and peer.core:legal()
-- Input: peer:choose {kind='move',slot=1}, switch/index, or forfeit.
-- Result: peer.result only appears after both full-state hashes agree.
-- Disconnect: peer:close(); construct again with peer.channel.room to replay.
```

`profileFilesystem` supplies `read`, `write`, `createDirectory` within the user's
active profile. The identity must include its edition/profile/slot/trainer, not
just a display name. Verified `.tmp` credential copies remain recoverable.
`normalizedImportedDataset` and `canonicalBattleParty` are the source engine's
existing xgen/g3u projections, not native Gen2 records. Unsupported moves/species
must be rejected by `g3u.Wire` before play. The source presenter keeps owning its
UI/input: this is an explicit companion integration, not a silent modification
of an installed Gen1 application. Bare Gen1 legacy relay rooms do not speak this
profile; both endpoints must choose the added feature.

The portable adapter currently provides synchronous battles. Durable native
Game3 trade commitment is owned by the fork's cable controller/journal. A Gen1
trade frontend must use its own native save transaction owner rather than
writing a Gen2 receipt into a Gen1 save.
