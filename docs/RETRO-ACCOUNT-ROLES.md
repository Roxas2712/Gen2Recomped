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

Starscream89 holds the existing `owner` grant. Protection follows the account and grant, not an editable nickname or one device. The native role endpoint only changes `retro_admin` and `retro_superuser` grants and cannot remove the owner grant. Moderation also checks raw active grants so suspension cannot bypass operator/staff protection. It cannot moderate itself. The operator has no removal or demotion action.

Moderation requires a reason, explicit action confirmation and the acting staff member’s current password. Bans revoke all device sessions. Cloud removal is a reversible quarantine: encrypted content and revisions remain recoverable, writes to held paths are blocked and local device files remain intact. This interface does not offer irreversible erasure. All moderation, role and cup access changes create an audit event. Staff status visibility does not override friends’ mutual map-sharing permissions.

Organizer additions never mark a player ready. Players must accept the rules and confirm readiness themselves. A running bracket cannot have its entrants silently replaced; organizers use the existing dispute/forfeit or cancellation controls.
