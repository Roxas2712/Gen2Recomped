# Pinball friend-service contract

Client integration by **Roxas2712**. This describes the service extension the
Pinball client requires. It is **not** a server implementation or confirmation
that the production service accepts these requests. The published public fork
contains the account client; its `main` tree does not contain the ModCompass
Laravel application. No production account or real friend was used in QA.

The existing signed-in device session and `/play` authorization apply. Keep the
existing friend, privacy, block, device, expiry and rate-limit checks. Pinball
must have its own mode; it must never enter the RPG battle/trade handlers or
accept a fabricated RPG party. Treat client scores as an unranked friend
challenge; no authoritative ranking or stake payout is defined here.

## Presence and invitations

`POST /play/presence` carries `edition="pinballrs"`, `fingerprint`, `available`
and `pinball={protocol:1,field:0|1,frames:18000,locale:"en"|"fr"|"de"|"it"|"es"}`.
The fingerprint is SHA256 hex of newline-separated `pinball-duel-v1`, ROM SHA1,
native backend/BIOS identity and content identity. It is a compatibility check,
not attestation. Other editions continue their existing handling.

The response retains the existing presence document with `account_id`,
`friends[].playing[]` and `invites[]`. Pinball device entries include `device`
(UUID), `edition`, `available` and `compatible`. Compatibility requires matching
edition and fingerprint. Presence should expire when the device stops polling;
the launcher only advertises readiness in Pinball/the friend workspace.

`POST /play/invites` receives `device`, `mode="pinball"`, `fingerprint`, and:

```json
{
  "rules": {
    "protocol": 1,
    "field": 0,
    "frames": 18000,
    "seed": 0,
    "rom": "<40-character SHA1>",
    "backend": "<native backend and BIOS identity>",
    "content": "<cartridge and locale identity>",
    "locale": "en"
  }
}
```

Validate bounded strings and the fixed protocol/duration/seed/enumerated fields.
Freeze rules at invitation creation. Reject a busy/stale device, different
fingerprint, blocked/nonfriend account or disabled incoming invitations. Only
the invited account/device may respond; no replay after decline/cancel/expiry.
Reserve both participants against conflicting active invitations atomically.

Invitation documents include `id` (UUID), `mode="pinball"`,
`edition="pinballrs"`, `state`, `incoming`, `host` and `peer` (account IDs as
strings), `nickname`, and the frozen `rules`. `peer` is always the *other*
participant relative to the recipient; `host` remains the inviter's account.

Existing endpoints remain:

- `POST /play/invites/{id}/respond` with `{accept:true|false}`.
- `POST /play/invites/{id}/cancel` cancels an unresolved invitation/round.
- `POST /play/invites/{id}/enter` receives `{fingerprint,rules}`. Revalidate
  participant/device, accepted state, fingerprint and exact frozen rules. Mark
  that participant ready and return `{ready:true}` only after both enter.
  Pinball sends no party, save, cartridge bytes or game assets.

## Ordered message transport

`POST /play/invites/{id}/wire` uses the existing CloudNet envelope:
`{battle:id,ticket:"",after:N,messages:[{sequence:N,body:"<JSON>"}],close:false}`.
Authenticate the invitation's two bound devices; only accepted and entered
Pinball participants can read/write it. Enforce the existing ordered,
idempotent stream and return:

```json
{
  "account_id": "<requesting account>",
  "battle": "<invitation UUID>",
  "sent": 3,
  "messages": [{"sequence": 1, "body": "<peer JSON>"}],
  "peer_online": true,
  "peer_closed": false
}
```

The client sends batches up to 8 messages / 96 KiB, a body up to 32 KiB and has
a 128-message queue limit. Acknowledgements must refer to contiguous accepted
sequence numbers, not the highest attempted number. Retry of the same sequence
and bytes is idempotent; different bytes for an existing sequence are rejected.
Return at most 8 messages after `after`, in order. Scope streams to participant
and invitation and retain final messages until acknowledged. Revoke wire access
on cancellation/expiry or account/device revocation. Do not reuse RPG trade
receipts, party validation or Arena result submission for this mode.

The inner protocol is `src/pinball/Duel.lua`: `pinball_duel`, protocol 1, native
identity hello, matching initial RAM checkpoint, host start, monotonic frame
and exact decimal score updates, keepalive and cancel. Disconnects award no
winner. Native preparation, the displayed countdown and gameplay timing remain
client responsibilities; server readiness does not skip the RAM handshake.

### Invite first, prepare the private import second

The friend workspace can send `{account:"<friend account>",mode:"pinball",
fingerprint,rules}` instead of a device-target request. The existing accepted
friendship and request/privacy checks still apply. The service selects that
friend's most recently seen authenticated device (ordinary menu heartbeat at
most 120 seconds old), then binds the invitation to it. This permits a pending
request before the recipient opens Pinball or imports a ROM. It does not mark
an unprepared device ready. Acceptance and entry still require matching native
rules, locale and fingerprint with fresh Pinball presence. An account change or
leaving the module cancels the local automatic import continuation.

### Optional side-by-side opponent picture

New clients advertise `view:2` in the existing protocol-1 hello. Both must agree
before sending `kind:"picture"` with monotonic `frame`, integer `width/height`
and base64 `png`. Original clients remain score-only. Native workers publish
completed pictures at up to six frames/second to a bounded latest-only queue;
a separate worker encodes/decodes them. At most 20,000 PNG bytes, 27,000 base64
characters and 512×512 pixels are accepted. Ancillary profiles and incomplete
chunk envelopes are rejected before decoding. No second game is simulated and
no ROM or save is shared. F7 hides/shows the large opponent pane.

These pictures currently use the existing HTTPS CloudNet fallback, including
its ACK/order/size limits. Their effective update rate depends on network and
server capacity. This is not a 60-fps video stream or qualification of Internet
P2P/relay video. Keep score/control messages usable if picture decoding fails.

## Validation handoff

`tests/pinball_friends_test.lua` drives two synthetic accounts through the real
Friends → CloudNet → Duel code: invite, accept, readiness, start, scores,
win/loss, decline, cancel, version mismatch, timeout and account change. Its
in-memory service is a contract fixture, not a replacement for server tests.
`tests/engine/friend_play.lua`, `cloud_net.lua` and `friends_menu.lua` protect
the existing RPG connection behavior.

Before enabling production, the server application needs its own tests for
participant authorization, device binding, stale presence, privacy, concurrent
invitations, immutable rules, duplicate/out-of-order wire requests and revoked
sessions. Then qualify the real invite/accept flow with two isolated test
accounts and native players over HTTPS, followed by separate physical devices.
The synthetic and localhost ENet tests alone do not establish that result.

The matching private ModCompass server implementation is saved on
`codex/pinball-friend-duels`, commit
`5b565c7394e7823559dde43ec0f757ff369e2039`. Its additive migration, affected
PHP files and deployment/rollback procedure are documented in that server's
README. The server checkout currently has no Git remote. Its 40 affected
PHPUnit integration/regression tests pass (565 assertions), including RPG
links, wagers and center lobbies. SQLite tests check reservation conflicts
sequentially; they do not certify simultaneous MySQL requests under load.

`tools/qualify_pinball_http.py` adds a different level of evidence: the actual
Laravel application over local HTTPS, two separate native LÖVE processes,
isolated authenticated accounts/profiles, real Friends/CloudNet/Duel modules,
matching initial native RAM, game inputs, consistent final scores and drained
final ACKs. The second client activates an already-built private import after
the invitation; this does not test ROM recompilation or browser OAuth. It does
not qualify the public service or separate physical devices. No production
account was used or modified, and these server changes have not been deployed
by this qualification.

Run the managed ROM-free client checks with:

```sh
python3 tools/qualify_pinball_friends.py --lua /path/to/lua
# Actual LÖVE LuaJIT runtime, also including launcher input routing:
python3 tools/qualify_pinball_friends.py --love /path/to/love
```
