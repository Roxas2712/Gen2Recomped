# Pinball qualification — 28 October 2026

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

## Before public release

Deploy the additive server migration and reviewed source pair using the
documented backup/rollback procedure; qualify authenticated public HTTPS with
two test accounts and separate physical devices. Run real concurrent MySQL and
capacity tests. The opponent picture currently uses bounded HTTPS CloudNet
fallback at up to six generated pictures/second, not 60-fps video. Internet
P2P/relay video and production bandwidth limits are still separate work.
Full-table rendering remains beta; not every bonus field, accessory or original
game event has been naturally played through. ROMs and private saves remain
outside commits and release packages.
