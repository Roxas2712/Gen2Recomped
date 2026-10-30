# Cable, relay recovery and synchronous battle QA

Contributions by Roxas2712. Reference `2aec7650cb01845a4e98f1dbcf8a5c652990d984`.

Final frozen snapshot: `nas-source-1793364954311501000`. All 13 suites passed serially on the NAS:
198719 explicit Lua checks plus four Python socket/SQLite cases. Suite runtime
was 26.595 seconds (snapshot/preservation/upload time excluded). No local tests,
parallel independent suites or GitHub workflows ran. CPU affinity was thread 7,
RAM 2 GiB including swap, extra swap zero, nice 15, container network disabled
apart from its own loopback. Temporary relay and peers ran inside one integration
case; no permanent NAS service or public listener was installed.

| Suite | Explicit checks | Result |
| --- | ---: | --- |
| `gen1_cable_session` | 43 | pass |
| `center_lobby` | 13 | pass |
| `gen1_cable_ui` | 21 | pass |
| `gen1_relay_server` | 4 Python cases | pass |
| `gen1_sync_battle` | 367 | pass |
| `gen1_g3u` | 917 | pass |
| `peer_net` | 19 | pass |
| `friend_trade` | 14 | pass |
| `api3_compat` | 126 | pass |
| `gen3_party_codec` | 194540 | pass |
| `gen1_link3` | 103 | pass |
| `gen1_gsc_simulation` | 1914 | pass |
| `native_session_runtime` | 642 | pass |

The socket case runs the production Lua TCP/channel/codecs and native trade
journal against the actual SQLite relay. A second phase runs the Gen1 companion
with the pinned source kernel against the native controller, reconnects it
mid-battle, compares verified results and checks that battle never writes the
adventure save. The socket client explicitly asserts its harness has no failures.
Relay cases cover crash/restart, hashed seat-token recovery, immutable message
keys, matching/mismatching decisions and forged client commits.

The transaction suite injects failed saves and disk-full preparation, replays
confirmed receipts, preserves divergent parties, checks native save/player/party
object identity, native counters and exact live/persisted equality, and retains
post-evolution move-learning receipts. UI cases drive room entry and native
stack retirement, imported catalog/genetics projection and frozen publications.
Center-lobby regression covers closing the overlay without losing its game,
active-upload admission and restoring the overlay after an entry failure.

Pinned source groups include 794 table, 49 wire, 21 isolation, 40 mechanics and
8 randomized/replay lockstep assertions. The wire group's source LinkBattle
export-alias assertions are explicitly excluded; the simulation/wire logic is
actual pinned source. Optional ASM/real-ROM cache probes are unavailable in the
isolated ROM-free snapshot, rather than being treated as tested ROMs.

SHA-256 source manifests, full logs and raw NAS evidence are retained privately
in `deliverables/gen1-cable-relay-20261030`. All changed source/test files matched
the final tested snapshot when preparing this report. [Feature setup and limits](GEN1-CABLE-RELAY.md)
explain the common pool, Gen1 companion, private relay, unsupported mail/movie/
USB-device paths and the absence of packaged desktop GPU/audio qualification.
