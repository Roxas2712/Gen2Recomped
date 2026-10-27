# RetroRecomped account roles

All signed-in players see the role badge beside a player’s name. A badge is informational; every privileged operation is authorized again by the server. Device identities share the account role.

| Capability | Player | Admin | Superuser | Protected operator (Starscream89) |
| --- | --- | --- | --- | --- |
| Play locally, import saves and compatible mods | Yes; no login needed for local play | Yes | Yes | Yes |
| Friends, inbox, directory, native online features | Verified account | Yes | Yes | Yes |
| Appear invisible to regular players | Yes | Yes | Yes | Yes |
| View true online/away status, including invisible accounts, and account counts | No | Yes | Yes | Yes |
| Create cups, set rules/prizes, manage registration and resolve disputes | No | Yes | Yes | Yes |
| Invite/remove/block cup participants before the bracket starts | No | Yes | Yes | Yes |
| Ban/unban and hide/restore public profile/avatar | No | Regular players only | Other non-protected accounts | Other non-protected accounts |
| Quarantine/restore cloud objects | No | Regular players only | Other non-protected accounts | Other non-protected accounts |
| Grant/revoke native Admin and Superuser roles | No | No | Non-protected accounts | Non-protected accounts |
| Ban, demote, remove or quarantine the protected operator | Never | Never | Never | Never |

Starscream89 holds a key-protected operator binding to fixed account ID 1 in the shared ModCompass database. Protection survives nickname changes and removal or expiry of ordinary role grants. Effective roles, moderation and account deletion enforce this binding; encrypted community backups include it. The native role endpoint only changes `retro_admin` and `retro_superuser` grants and cannot release the binding. The operator cannot moderate itself.

Releasing or rotating the binding requires its private recovery key through the interactive `retro:operator-lock` server console command, plus explicit confirmation. The server stores only a SHA-256 digest; no recovery key belongs in source, logs or public APIs. Release removes the binding and role grants and revokes sessions, while keeping the account and cloud data. A fork using the same backend retains the binding. An independent server/database administrator can modify their own implementation and is outside this protection boundary.

Moderation requires a reason, explicit action confirmation and the acting staff member’s current password. Bans revoke all device sessions. Cloud removal is a reversible quarantine: encrypted content and revisions remain recoverable, writes to held paths are blocked and local device files remain intact. This interface does not offer irreversible erasure. All moderation, role and cup access changes create an audit event. Staff status visibility does not override friends’ mutual map-sharing permissions.

Organizer additions never mark a player ready. Players must accept the rules and confirm readiness themselves. A running bracket cannot have its entrants silently replaced; organizers use the existing dispute/forfeit or cancellation controls.
