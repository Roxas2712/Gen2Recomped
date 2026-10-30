# Optional Gen1 compatibility features, revision 1

Contributions by Roxas2712; existing Gen1Recomp / BOIS CLUB GAMES rights remain
in effect. Reference: `2aec7650cb01845a4e98f1dbcf8a5c652990d984`.

API-3 mods receive `mod.features.gen1`. Every operation is explicitly selected;
installing a mod does not start an alternate game, change a native save version,
or switch native link negotiation. Capabilities use `mod:supports('features', name)`.

| Capability | Contract |
| --- | --- |
| `gen1.battle-simulation-v1` | Detached GSC source engine, all native hosts |
| `gen1.world-session-v1` | Active native Game3 world, GBA hosts |
| `gen1.save5-v1` | Explicit Red/Blue/Yellow Save-5/Save-4 data conversion |
| `gen1.link3-codec-v1` | Gen1/2/3 party wire conversion against mounted catalogs |
| `gen1.link3-trade-v1` | Protocol-3 GB trade state machine, Gen1/2 hosts |
| `gen1.cable-lobby-v1` | Additional native lobby/room-code/consent UI, Gen1/2/3 |
| `gen1.relay-recovery-v1` | Durable private relay transcript and native Game3 trade receipts |
| `gen1.sync-battle-v1` | Explicit shared g3u kernel and hash barriers, Gen1/2/3 |
| `gen1.gba-exchange-v1` | Game3 offer/block/commit data verifier, GBA hosts |

## Detached GSC battles

```lua
local feature = mod.features.gen1
local battle, namespace = feature.battle.new {
  version = 'crystal', seed = 2712,
  data = sourceShapedCatalogs, party = sourceShapedParty, wild = sourceShapedWild,
  save = optionalSourceShapedSave,
}
local events = battle:takeTurn { kind = 'move', move = 'TACKLE' }
```

This is the pinned source Battle class with its constructor, turn processing,
two-party `takeLinkTurn` and event queue. It expects source GSC catalogs and
records (`specialAttack`/`specialDefense`, source move effects and battle rules).
It does not reinterpret native records. All input data, party, wild, trainer and
save tables are copied together; references within that graph are preserved.
An instance owns its module cache, edition, random stream and passive event bus.
`onEvent` and `hooks` callbacks can be supplied explicitly. They are ordinary
trusted callbacks and can perform their own side effects.

`feature.battle.bundle(options)` exposes the same isolated namespace for advanced
source modules; objects constructed directly there are owned by the caller.
The trusted source inventory is fixed. This is not a sandbox for arbitrary Lua.
The engine is the pinned implementation, including its own modeled-effect limits;
it does not replace the native battle model or provide cross-engine lockstep.

## Native Game3 world sessions

```lua
local world, why = feature.world()
assert(world, why)
local position = assert(world:load('MAP_PALLET_TOWN', {
  x = 8, y = 9, facing = 'down', enterVia = 'warp', keepMusic = true,
}))
assert(world:queueScript(nativeScriptRows))
assert(world:enqueueWarm('MAP_ROUTE1'))
world:stepWarm()
```

Map IDs resolve through the imported ROM group/number identity; native map keys
also work. Coordinates must be valid cells in the actual native map. Loads call
the existing world loader once; the player, scripts, collision and resources stay
with that native owner. `queueScript` takes native script rows, not an invented
source VM. Covering UI and active native operations retain admission control.
`enterVia` accepts `warp`, `connection`, `continue` (native boot arrival policy).
`initialLoad` is rejected because boot owns it. Unknown semantic options reject.
Native map errors propagate; this API does not add transactional map rollback.

`warmNow`, `enqueueWarm`, `stepWarm` submit native prefetch requests; they do not
poll workers or advance resource clocks. Queued requests deduplicate within one
map epoch. Replacing the game, save, data or edition retires active operations.
`release()` retires a handle. API-3 mod rollback, reload and teardown release
its handles and open trade leases; retained handles cannot write after retirement. `Game3:worldSession()`, `Game3:loadMap()` and optional
`game3.map.load/warmNow/stepWarm` use this same native-owned implementation.

## Explicit Save-5 conversion

```lua
local detachedSave4, report = feature.save5.import(sourceSaveBytes)
assert(detachedSave4, report)
local save5Bytes, exportReport = feature.save5.export(detachedSave4)
```

Upstream `meta.format=5` is a Gen1 save contract. GSC uses its own format and
Game3 uses its own schema; these must not be relabeled as Save-5. The converter
validates supported edition, saved destination, party/boxes/moves and target
catalog IDs. It preserves unknown data-only fields, OT identity and exact finite
numbers. Already migrated Save-5 OT data is not repaired a second time. Functions,
metatables, cycles, invalid destinations and unsupported schemas reject. Maximum
input/output is 16 MiB. A report records `nativeWrites=0`. No profile or file is
read or written, and the caller's record is never modified. Selecting/committing
a save remains an explicit native storage operation.

## Link-3 data and GB trade sessions

```lua
local codec = assert(feature.link3.codec())
local packet, why = codec.packMon(nativeMon)
assert(packet, why)
local detachedMon = assert(codec.unpackMon(nil, receivedPacket))
```

Classic species/move/item identities use mounted portable identities. GBA uses
actual imported cartridge indices, not National Dex numbers. Receivers rebuild
native stats and validate species, moves, PP, IVs/DVs, EVs, ability and ownership.
GSC experience/status fields, caught fields and whole egg cycles translate
explicitly. Fractional egg cycles, opaque caught words, source-omitted sleep
counters, unsupported GBA extension/mail data and clipped names reject rather
than silently losing data. Maximum inspected packet is 8 MiB.

For Gen1/2, `feature.link3.hello()` explicitly advertises protocol 3 with an honest
native engine version and namespaced fingerprint. `newTrade(peerHello)` accepts
an unmodified foreign engine with the same major release and generation. It
returns a native trade session with `opening`, `handle`, `pick`, `cancelPick`,
`confirm`, `reset`, `apply(game)`, `close` methods. The transport sends returned
messages. This is the trade-only profile: it does not claim fingerprint equality
or battle lockstep. Native protocol 2 remains the default.

The session leases the active native link owner, freezes local party content,
validates message phases and peer slots, and uses the existing native receipt,
Pokédex and held-item evolution paths. `apply` commits once after both peers
confirm. Replaced parties, changed game owners, repeated peer offers/selections
and out-of-phase confirmations abort. A decline may be reset; mutual cancel
releases the lease. Call `close()` when a transport disconnects.

## Game3 block/commit verification

Game3 uses its own envelope, not the GB party/pick/confirm state machine. After
an external transport has negotiated seats and offers:

```lua
local exchange = assert(feature.link3.gbaExchange(codec, myPacket, peerPacket, {
  seat = 0, afterRound = lastCommittedRound,
}))
local block = assert(exchange:block { name = trainerName, trainerId = trainerId })
-- send block, then receive the other seat's block
local confirmation = assert(exchange:receive(peerBlock))
-- send confirmation, then receive the relay's commit
local candidate, receipt = exchange:accept(relayCommit)
```

This verifies the exact source wire sanitizer, ordered-seat canonical digest,
unchanged advertised offer, both relay digests and a strictly newer commit round.
A candidate is detached data; `receipt.nativeWrites=0`. Duplicate commits and
swapped blocks cannot apply. `abort()` releases an unfinished exchange.

`gbaExchange` remains the pure data-plane verifier. The additional
`feature.link3.openCable()` integrates room creation/join, native party/consent
UI, durable relay decisions, native save receipts and interrupted-session
recovery. The added `feature.battle.sync()` supplies a shared-kernel battle
mode. See [the setup, common-rule limits and Gen1 peer adapter](GEN1-CABLE-RELAY.md).
Mail-block transfer and a trade movie are outside this menu-based cable feature.

## Validation

Run the dedicated `gen1_gsc_simulation`, `gen1_world_session`, `gen1_save5`,
`gen1_link3` suites and native regression suites through `tools/nas_qa.py`.
All suites run sequentially in the resource-limited NAS container; no local test
execution or GitHub Actions is necessary. The source implementation and raw
SHA-256 provenance are in `src/features/gen1_gsc/`.
