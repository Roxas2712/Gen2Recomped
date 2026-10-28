# One-time local minigame content setup

Contributions by Roxas2712. This is a technical workflow, not a legal clearance.

## Player flow

The game code stays installed as one application. The initial mandatory notice
is followed by a single shared content setup. There is no account requirement.

* **Use basic graphics** immediately uses procedural figures, tokens and
  backdrops. Rhythm Tap synthesizes its own sound. No cartridge images or
  painted course images load in this mode. Names, rules and existing reward
  data have not been renamed or claimed as independently owned content.
* **Prepare imported graphics** cycles through existing local imports. The
  application snapshots that edition's available front/walking images, shows
  source, credits and usage notices, then requires an unchecked permission
  confirmation and a separate preparation action. No reimport is necessary.
* **Import content pack** selects one `.mgpack` file. It is a ZIP containing
  a data-only `minigames.lua` descriptor and its PNG files. Desktop drag/drop
  also works while setup is open. Without the native picker, place the same
  file at `minigames/import.mgpack` in the active profile and choose Import.
  The existing generic inbox reader bounds this fallback archive to 8 MiB;
  the desktop picker accepts archives up to 64 MiB.

After selection, later entries go directly to the minigames. **Content &
graphics** reopens setup. Back/cancel preserves the previous selection.
**Friends & cloud → Withdraw minigame acceptance** works for guests too;
it retires the open run without a new payout and invalidates the content
selection. Copies are preserved locally, rather than deleting player files.

Each profile/device keeps its own receipt. Content and consent are excluded
from the Pokéwalker cloud snapshot. Rules, scores, saves, reward limits and
friend/account services are not supplied by content packs. No server change,
migration, download service or public asset redistribution is involved.

## Format 1

The descriptor uses the existing restricted `PackData` literal-table parser;
the `.lua` extension does **not** permit executing code. Example:

```lua
return {
  format=1, name="My local graphics", source="Describe your source",
  credits="Relevant authors and rights holders",
  terms="Applicable permission / usage information; not a project licence",
  entries={
    {key="front/25",file="images/25.png",size=1234,
     md5="0123456789abcdef0123456789abcdef",width=64,height=64},
    {key="walk/25",file="images/25-walk.png",size=2345,
     md5="0123456789abcdef0123456789abcdef",width=32,height=64,
     frameWidth=32,frameHeight=32,
     facings={up={0,1},down={0,1},left={0,1},right={0,1}}},
  },
}
```

Sizes, dimensions and checksums above are placeholders; actual files must
match. Frame indices are zero-based, row-major. Keys identify national-dex
motifs for the shared renderer. A pack contains only appearance, never a
roster, item grant, script, URL or multiplayer rule. Missing/corrupt images
fall back to the procedural figure, never a different imported cartridge.
Source/credit/terms are supplied descriptions, not verified proof of rights.

Limits: 2,048 entries, 8 MiB per PNG, 64 MiB of declared files, at most
2,048×2,048 pixels per image and 16 million declared pixels in total.
Absolute/traversing paths, duplicates, incompatible frame grids and changed
checksums are refused. PNG dimensions are checked before decoding. MD5 is the
existing pack format's integrity identifier, not authentication or a licence
verification mechanism. Only supported PNG assets are loaded; audio bundles
and executable animation metadata are deliberately outside format 1.

Review does not install anything. After explicit acceptance, immutable objects
are verified and staged through the existing publication/save-safety helpers.
The selection changes only after the complete pack is present. Cancelling or
switching profiles never publishes a partially installed choice. A local
preparation coroutine checks profile identity at every yield. Imported cache
files and source archives are never rewritten or removed.

Storage: `minigames/content/objects/<digest>.png`,
`minigames/content/packs/<digest>.lua` and `selection.lua`, routed through
`ProfileFs`. Files remain local to the profile; credentials are absent.
Changing descriptor contents or the notice version invalidates the selection.

## Coverage and integration boundary

The five shared Walker games are integrated and tested: Jump Runner, Catch
Timing, Treasure Hunt, Memory Match and Rhythm Tap. Their mechanics and
reward/sync paths are preserved. Pinball is a separate native GBA title with
its own cartridge import; it is not one of these asset packs.

Slide and Warsheep currently exist in a separately edited private checkout.
Their direct media paths and audio/animation metadata require dedicated
adapters before this format may be advertised for them. Merely adding them
to the hub list would bypass the resolver and is not a completed migration.
That checkout's uncommitted work is not overwritten by this branch. No claim
of a complete seven- or nine-game conversion is made here.

## Validation

`tests/engine/minigame_content.lua` checks publication, changed bytes/terms,
profile changes, cancellation boundaries, validation and notice revisions.
`tests/engine/minigame_enrollment.lua` covers the separate mandatory gate.
The existing 127-check rules suite still verifies game/reward behavior.

`tools/qualify_walker_online.py --content --label UNIQUE --love /path/to/love`
uses isolated profiles and generated test pixels for real ZIP mounting, PNG
decoding, actual profile paths, restart persistence, five-game basic smoke
and portrait/landscape rendering. This is not a native cartridge duel, a
live server test, a legal review or verification of third-party pack rights.
