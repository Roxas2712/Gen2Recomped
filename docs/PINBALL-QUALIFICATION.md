# Pinball qualification — 28 October 2026

## Public-service follow-up (demo v28)

The reviewed additive migration and server sources are now installed on the
public ModCompass service. A real two-process native duel used public HTTPS
for invitations, entry, ordered score/control data and final acknowledgements;
opponent pictures used Internet WebRTC and then a deliberately forced public
WSS relay fallback. This is a same-Mac test with separate accounts/profiles,
not a physical-device or cross-NAT qualification. Browser OAuth was not tested.

| Follow-up check | Result |
| --- | --- |
| Server regressions | 46 tests / 648 assertions passed, including existing RPG play, wagers, center lobbies and peer transport. |
| Actual public native duel | Both games started from checkpoint `5b0ac80b64d59d2294636f72c79e4b5d3357c78b`; scores 166,800 / 5,000 agreed on both clients, with complementary win/loss. |
| Final public MySQL tail | Finished invitation; receive cursors 414 / 398 matched opposite sent cursors; zero remaining message bodies. |
| Actual opponent pictures | 859 / 820 received; both used direct WebRTC and WSS relay. Large side-by-side boards and route indicator inspected. Pictures are bounded previews up to six per second. |
| Steady audio | Zero restarts on both clients over 126.46 / 125.88 seconds after the 60-second warm-up. Startup and scripted window transitions still recorded 4 / 12 restarts under concurrent QA load; uninterrupted audio under every workload is not claimed. |
| Background presentation | USA/Ruby and Europe/German/Sapphire: each 1500 PCM blocks byte-equal to foreground presentation, 26 RAM/picture checks equal and exact 40-frame hidden-state replay passed. Canonical guest PPU and game frames remain active. |
| Bundled transport | Six isolated signed app instances passed direct, forced relay and mid-stream failover, 24 ordered messages each; default library/CA discovery, with developer library overrides removed. These are transport fixtures, not six native games. |
| Public relay | Five actual Worker tests passed: authentication, signal/data/ACK/renewal, forged/expired tickets, replacement/replay, invalid/oversized messages. Existing public Worker reused; no new Worker deployment. |
| Public control load | 5 sessions: p95 1090 ms, max 1726 ms, 100 requests; 10 sessions: p95 1757 ms, max 2385 ms, 160 requests. Both error-free with final tail drained. At 20 sessions the five-second safety window was exceeded and the test stopped. |

The load test uses synthetic protocol pings, at most eight concurrent HTTP
requests, periodic presence and no images, ROMs, rewards or native games. Its
one-request/client/second target slowed under queuing. It does not establish
capacity for 20 played games or full Internet media bandwidth. Ten sessions is
the highest completed control-load stage, not an enforced server admission cap.
A global admission queue or more server headroom is required before advertising
higher concurrency. Existing heavy RPG-verifier limits remain separate.
All 42 disposable roleless public QA accounts were removed after these tests.
No real user account, role, ROM or private save was changed.

### Fixes qualified by this follow-up

Audio Source ownership and pumping moved to the native worker; short scheduling
stalls retain guest deadlines, and pause/mute discard queued audio deliberately.
Hidden windows skip only extra full-table host composition between six-Hz
previews, preserving canonical rasterization, audio and exact guest state.

The public MySQL REPEATABLE READ run exposed a real final-message race: locked
peer counters could be newer than ordinary snapshot message reads. Current
locking reads now cover duplicate detection, unread limits and message pages.
The operator-only two-connection fixture reproduced the old 409 and passed with
the fix. An optional `peer_sent` watermark prevents a close flag from retiring
CloudNet before the final delivered tail and its ACK.

Pinball pictures negotiate an optional independent PeerView channel. ModCompass
authorizes its existing device/friend-bound tickets; WebRTC is preferred, WSS
relay is next, and existing HTTPS picture transport remains the fallback.
Scores, rules, cancellation and final result messages stay on CloudNet. Client
results remain unranked friend results, not a server-authoritative leaderboard.
Portable TLS libraries, CA certificates, licenses and pinned source provenance
are included with the demo; no cartridge or cartridge-specific compiled library
is bundled.

Reproduction tools: `qualify_pinball_public.py`, `qualify_pinball_load.py`,
`qualify_pinball_presentation.py`, `qualify_packaged_peer.py`, plus the existing
local `qualify_pinball_http.py` and source suites. Public tools require explicit
private disposable-account fixtures; there is no public QA-account endpoint.
The private server checkout has no configured remote; its changes are committed
on `codex/pinball-friend-duels` at `9a1c22b`. Deployment backups and credentials stay private.

### Remaining qualification

Two physical machines behind different NATs, mobile/controller hardware, browser
OAuth, longer soak tests and every original bonus field remain unqualified.
A UI stress transition can still starve startup audio. The measured steady
window passed; universal stutter-free operation is not promised.

## Earlier demo-v27 results (superseded where noted above)

Integration by Roxas2712. This report distinguishes source tests, actual local
HTTP applications, actual native games and public deployment.

| Check | Result |
| --- | --- |
| Server PHPUnit integration/regressions | 40 tests, 565 assertions passed: Pinball, existing RPG play, wagers and center lobbies. Pint passed on all affected PHP files. |
| Client Lua regressions | 310 synthetic friend-service checks, 50 duel checks, 19 launcher checks and affected save, layout, live-picture, audio, controls, account, friendship, CloudNet and frame-pacing suites passed. Synthetic checks are not server/live-game tests. |
| Runtime patch upgrade | Existing HALT-only build upgrade, repeat application, conflict refusal and preservation of all unrelated files passed. |
| Native raster | HUD and OBJ-layer tests passed. Independent mGBA captures reduced the incorrect pixels above the monitor from 464/1287 to zero at the two inspected frames. |
| Actual cartridge cadence | USA/English/Ruby and Europe/German/Sapphire each advance 240 game steps for 240 VBlanks and produce exactly 4.01824951171875 seconds of PCM. |
| Native state/render regression | Both cartridges match 6000 cached/reference images and 56 RAM checkpoints, exact 40-frame quick-state replay and legacy-state loading; 120 full-table HUD frames per cartridge passed. |
| Actual single-player display | German/Sapphire: 1195 distinct pictures in 20.0027 seconds, about 59.74/s, zero audio restarts. This earlier isolated display run does not certify every later online workload. |
| Two actual native clients over local HTTPS | Invitation, accept-after-private-import activation, matching initial native RAM, joint start, native gameplay, live opponent pictures, consistent win/loss and final server-message drain passed. |
| Strict online audio target | **Not met.** The last two-client run had one steady-state restart per client during about 142 seconds after warm-up. Do not report it as a fully stutter-free audio qualification. |
| Public ModCompass / physical devices | Not qualified or deployed by these tests. No production account was modified. |

The last actual native run used two independent LÖVE processes and profiles,
the existing Friends/CloudNet/Duel/Player/native-worker modules, an isolated
Laravel database and actual HTTP behind a local HTTPS proxy. Test sessions were
injected; browser OAuth was not exercised. The recipient activated an existing
private compiled import after receiving the request, rather than recompiling
the ROM during the test. Controls were delivered as guest input, not RAM edits.

Both games began with checkpoint
`5b0ac80b64d59d2294636f72c79e4b5d3357c78b`. Their final scores were 25,500 and
2,000; each client agreed on both scores. They received 389 and 422 opponent
pictures, ended with complementary win/loss and drained all final wire data.
The first database check exposed a missing final ACK despite correct displayed
results. Pinball now opts into strict CloudNet close: wait for both peers, drain
every final page and ACK the current receive cursor before retiring. A new
transport regression and the repeated actual native run cover that fix.
A read-only post-run database check confirmed one finished invitation and no
unacknowledged message bodies. The pictures were inspected in the actual final
renderer: the local board and friend's board are large and side by side.

macOS App Nap protection increased picture delivery from roughly 20 pictures
in the earlier minimized-window run to roughly 400. It removed the sustained
background starvation. Native waiting/completion audio now ends deliberately;
solo pause releases the activity lease. The host menu discards continuing duel
audio so it cannot replay late on resume. A six-frame audio preroll provides
about 100 ms of reserve without stretching samples or changing game speed.

The QA screenshot/minimize operations deliberately block a main-loop transition
for about 600 ms and caused startup-phase restarts. The separate steady-state
counter excludes the first 60 seconds; its remaining one restart per client is
still a failed zero-starvation target, not excused as a successful test.
Further producer/output timing measurements are needed before promising
uninterrupted online audio under simultaneous native workloads. The dispose/draw guard and paused-menu audio discard also have focused Lua
regression coverage; the final native run includes those changes.

## Changed implementation areas

- Native runtime patch and builder: `tools/pinball-rs-native/runtime-fixes.patch`,
  its CMake test target, `tools/pinball_rs.py` and patch qualification.
- Module page and SRAM: `LauncherPinball.lua`, new `LauncherPinballPage.lua`,
  `SaveFiles.lua`, and the launcher translation catalogue.
- Friend preparation: `Friends.lua`, shared `cloud/Play.lua` polling and the
  extended service contract in `PINBALL-MODCOMPASS.md`.
- Large opponent view/audio: `Player.lua`, `worker.lua`, `Activity.lua`,
  `Duel.lua`, `LiveView.lua`, `LivePicture.lua`, `live_view_worker.lua`.
- Repeatable native HTTPS qualification: `tools/qualify_pinball_http.py`,
  `tests/pinball_http_peer.lua`, plus focused client/native regressions.
- Private server branch `codex/pinball-friend-duels`, commit
  `5b565c7394e7823559dde43ec0f757ff369e2039`: `RetroPlay.php`,
  `RetroPlayController.php`, additive migration, feature tests, isolated HTTP
  fixture and server README with deployment/rollback instructions. The checkout
  has no configured remote, so no server PR URL is claimed.

## Earlier release prerequisites (status updated above)

Deploy the additive server migration and reviewed source pair using the
documented backup/rollback procedure; qualify authenticated public HTTPS with
two test accounts and separate physical devices. Run real concurrent MySQL and
capacity tests. The opponent picture currently uses bounded HTTPS CloudNet
fallback at up to six generated pictures/second, not 60-fps video. Internet
P2P/relay video and production bandwidth limits are still separate work.
Full-table rendering remains beta; not every bonus field, accessory or original
game event has been naturally played through. ROMs and private saves remain
outside commits and release packages.
