# GBC Pinball ModCompass extension

Contributions by Roxas2712. These original edition rules and configuration
examples belong to the public Gen2Recomped fork. They contain no existing
private backend implementation, operator credentials or accounts.

`RetroPinballGbcRules.php` is the GBC edition-specific validator. The existing
ModCompass server must continue to supply authentication, accepted friendships,
privacy/block checks, bound device sessions, invitation reservations, immutable
rules, monotonic scores, ordered/idempotent messages, final acknowledgements
and peer-ticket authorization. This file is not a standalone server.

## Connect to the deployed server

1. Copy the class into the deployed Laravel application's `app/Services/`.
2. Extend its Pinball edition selector with `RetroPinballGbcRules::supports`.
   For GBC presence, call `RetroPinballGbcRules::presence`; for invite creation,
   acceptance and entry, call `RetroPinballGbcRules::validate($rules, $fingerprint)`.
   Convert `InvalidArgumentException` into the existing 422 validation response.
   Preserve the current GBA branch and every common authorization/wire check.
3. Ensure account- and device-target invitations, existing invitation views and
   peer-ticket authorization preserve `pinballgbc` as its own edition. Reuse the
   existing protocol-1 score/picture envelope checks; do not enter RPG handlers.
4. Run the deployed application's GBA/RPG and GBC integration tests before
   changing the live release. No route, database or permission bypass is added.

Actual adapter insertion points require the deployed server's current source.
They have not been inspected or applied by this extension. The examples below
are deliberately unconfigured, and no live GBC qualification is claimed.

Copy `deployment.env.example` and `accounts.example.json` into a private ignored
folder and fill in the requested placeholders. The account fixture must contain
two distinct disposable roleless accounts with an accepted friendship and
revocable device tokens. Its 32-character hexadecimal marker identifies the
operator's fixture for later cleanup. Store it with mode 0600; never commit it.
The public test runner rejects placeholder or duplicate-account fixtures before
starting a client or making an authenticated request.

## Run the real test when configured

```sh
python3 tools/qualify_pinball_public.py --edition pinballgbc --field 0 \
  --fixture /private/qa-accounts.json --love /path/to/love.app/Contents/MacOS/love \
  --peer-mode off --label gbc-live-red
```

This uses actual public HTTPS for invitations, import continuation, native game
start, original cartridge gameplay, opponent pictures, scores and final ACKs.
It does not create accounts or send invitations to anyone outside the fixture.
The default also requires the original strict steady-audio qualification.
`--functional-only` explicitly separates a functional test from that audio goal.
Use field 1 for Blue. For WebRTC/WSS and deliberate failover, pass
`--peer-mode switch --peer-library /path/to/libretro_peer.dylib --peer-ca /path/to/cacert.pem`.
The operator must verify the final server tail and remove only its marked
throwaway accounts after the run. No service changes or test accounts are
created by merely copying these templates.
