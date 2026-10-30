# Additional cable lobby, durable relay and shared battles

Contributions by Roxas2712. This is an explicitly selected feature profile;
the normal native Save-4/Link-2 paths keep their existing contracts.

## Enter the feature

In a Pokémon Center open **Optional · Compatibility Cable**. API-3 mods can use:

```lua
local screen, why = mod.features.gen1.link3.openCable()
assert(screen, why)
```

The native overworld must own the screen. Game3 offers host/join trade, host/join
shared battle, retained room recovery and an editable relay address. Gen1/2 hosts
offer the shared battle mode. Native input operates the room-code editor, party
selection, explicit final trade consent, battle moves/switches/forfeit and return.
The additional battle presentation shows native names, HP, action feedback and
a verified result. It uses the engine's font and native stack; it does not load
the proprietary Gen1 launcher UI. Mod retirement closes its retained sessions.

Capabilities: `gen1.cable-lobby-v1`, `gen1.relay-recovery-v1`,
`gen1.sync-battle-v1`. Pure callers can construct `battle.sync(options)` with
canonical g3u table/party records and operate its action/hash barrier directly.

## Private relay

The small, single-threaded relay is an on-demand Python standard-library tool:

```sh
python3 tools/gen1_session_relay.py --host 127.0.0.1 --port 7780 --db /private/path/gen1-relay.sqlite
```

For separate machines bind to an explicitly chosen private LAN/VPN interface
and enter its address in both lobbies (or set `GEN1_FEATURE_RELAY`). The default
is `127.0.0.1:7780`. It is independent of the existing public/account relay.
This change installs no service, opens no router port and deploys nothing to
Cloudflare or GitHub. Outside a trusted LAN, use a VPN/TLS termination; the TCP
seat credential is a bearer token. Keep both the database and client profile
private. Do not copy an active seat token to another player.

A host receives an eight-character code. The joining player reserves the other
seat; their credentials survive disconnects. Reconnecting with that seat replaces
its old socket and replays the durable transcript. Mode and the pinned feature
profile must match. The relay stores token hashes rather than raw recovery tokens.
It refuses changed messages under an already published key, forged client commit
messages, excess clients/rooms/events and oversized frames.

There are at most 16 live sockets, 64 retained rooms, 4,096 events per room,
32 KiB per frame and 2 MiB queued output per socket. SQLite is limited to roughly
96 MiB of main database pages; its WAL is additional. Existing recovery evidence
is never age-deleted. At a budget limit new work is refused; preserve completed
journals before deliberate maintenance. The tool does not require Docker or a
permanent NAS daemon. QA alone uses the NAS's CPU-7/2-GiB container limits.

## Game3 trade recovery

1. Both clients publish immutable, validated party offers and selected slots.
2. Each player explicitly approves the shown pair. Blocks must still equal the
   corresponding advertised Pokémon, including ownership, moves and metadata.
3. The local profile journals the original party, slot, peer packet and digest
   **before** publishing confirmation. Disk-full preparation cannot consent.
4. SQLite commits both matching confirmations and the relay decision in one
   transaction **before** broadcasting it. A replay has the same round/decision.
5. Each client journals that verified decision before native save commitment.
   A receipt marker is saved with the received Pokémon; crash recovery cannot
   apply it a second time. Changed parties/profiles are retained and refused,
   rather than overwritten. A failed native write restores the live old party.

New GUI trades checkpoint the native adventure first, establishing its durable
playthrough identity. A successful transaction keeps the live native save,
player and party-array owners, replaces only the received slot, updates Pokédex
and native trade/evolution counters, and uses native held-item evolution rules.
The existing native move-learning UI handles evolved exact-level moves; a saved
learning marker prevents repeated prompts and keeps interrupted learning in the
recovery menu. Complete low-level journals are retained for review.

Leaving after confirmation means **resume later**, not proof of cancellation:
the relay may already have committed. A resumable profile record remains visible.
Mail blocks are still explicitly unsupported; a mail-bearing input is refused.
There is no added trade movie or USB-cable/device protocol. The added UI is a
native menu/consent flow over the verified block/commit protocol.

## Cross-engine synchronous battles

Both ends select the same pinned g3u kernel, canonical seats, rules table,
advertised validated party records and shared durable seed. Each decision step
waits for both full-state/RNG hashes. Both actions resolve independently in the
same kernel; forced replacements also cross a hash barrier. Divergent hashes,
illegal actions and changed/reordered confirmed frames stop the match.
A result becomes visible only after both final hashes agree.

This is an **additional common-rule mode**: Gen3 mechanics, abilities and held
items disabled, no adventure wounds/PP changes/EXP/money/rewards. Native Gen1/2
math is not treated as identical to native GBA math. Classic DVs map explicitly
to the common Hidden Power IVs (`2*DV+1`); native GBA IVs/PID must exist. The
current common pool is at most 151 species/165 moves for a Gen1-hosted table or
251 species/251 moves for a Gen2/GBA-hosted table. Unsupported effects are marked
illegal and refused before play. Heal the selected party first. Data/catalog
mods may produce an unsupported common table; the UI reports that admission
failure. This is unranked friend play, not an anti-cheat or competitive service.

After a reconnect or process restart, replay reconstructs the kernel from the
original table/parties/seed and confirmed actions; it does not accept a peer's
fabricated damage, HP or RNG snapshot. The adventure save is not rewritten.

For a Gen1 engine peer, the portable adapter is in
[compat/gen1_session](../compat/gen1_session/README.md). It uses the pinned
Gen1 engine's own original g3u modules and supplies the matching relay/session
protocol. Both ends must opt into this profile. A stock legacy Gen1 online room
cannot automatically connect to the new relay. The companion exposes its
normalized events to its owning Gen1 presenter; it does not silently patch an
installed Gen1 application or its save transaction owner.

## Evidence and limits

All tests run serially through `tools/nas_qa.py`. The real-socket integration
runs the production Lua TCP/channel/codecs, a SQLite relay, native trade save
commitment, and the Gen1 companion against the native client. It disconnects
and reconnects the companion mid-battle, verifies matching outcomes and checks
that the adventure save and write count remain unchanged by battle. Separate
cases cover relay restart, token recovery, changed messages, duplicate commits,
disk-full preparation, native save failure/retry, divergent saves, native object
identity, evolution learning receipts, source mechanics/isolation and UI input.
Independent suites never run in parallel; clients of one network case exchange
messages within that single serial integration test.

These are ROM-free/headless checks. They do not establish two packaged desktop
applications' GPU/audio presentation, public Internet hosting, USB devices or
all native source cartridge mechanics. The private relay is provided as a tool;
it has not been installed as an always-running NAS service.
