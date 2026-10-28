# Native FR/LG introduction before field admission

FireRed and LeafGreen created an overworld before their native Oak
introduction completed. The shared Game3 facade therefore reported `field`
while the introduction still owned the screen and input. A boot decorator
waiting for the destination renderer could keep its loading presentation
active indefinitely, preventing the introduction from progressing.

The configured native `Gen3OakSpeechFRLG` screen now retains boot ownership
until its existing completion callback starts the world. This follows the
existing Ruby/Sapphire introduction lifecycle. The world constructor reads
the final native player name, gender and destination, and the previous
overworld pointer is retired. The existing save-identity and once-only guards
reject stale or repeated completion callbacks.

No phase labels are synthesized for unrelated menus. The native introduction,
its controls, text, naming screens, save adoption and world constructor remain
responsible for their existing operations. Gen1, Gen2, Emerald and explicit
no-introduction datasets retain their established paths. Private mods do not
need changes.

## Regression coverage

`luajit tests/engine/gen3_new_game_lifecycle.lua` exercises the actual
`Game.newGame` entry and Game3 phase observation with a recorded native-world
constructor boundary. FR/LG completion uses the actual Oak screen's `finish`
method. The cases cover retired world pointers, final introduction answers,
replacement saves, duplicate completion, RS and no-introduction controls,
and Emerald's existing lifecycle. Before the fix, 16 FR/LG assertions fail.

`luajit tests/engine/gen2_new_game_lifecycle.lua` retains the existing Gen1,
Gen2 and RS lifecycle checks. CI also checks native boot callbacks, audio
shutdown, entry-world ownership and coroutine phases. These ROM-free
contracts are separate from an unchanged-package, fresh-profile graphics
test; they do not establish full story, device or performance acceptance.

Contributions by Roxas2712. Existing notices and licences remain applicable.
