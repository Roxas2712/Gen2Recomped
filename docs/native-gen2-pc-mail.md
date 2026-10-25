# Native GSC PC and mail

The Gen2 PC host previously failed while requiring `src.core.gen2.Mail`.
Its `Boxes` compatibility name also exposed the shared storage module,
whose `count()` counts boxes rather than residents. Native script mail
commands were stubs, and Gold/Silver mail pointers consumed an extra byte.

The native Gen2 adapters now operate on the existing save's party, fourteen
20-member boxes and ten-entry mailbox. Deposit gates reject held mail and
the last healthy member; deposit/withdraw restore native PP/HP/status.
Party reorders and native removals shift slot-indexed letters with their
carriers. Missing-carrier letters are retained through save validation.

Mail is recognized from the imported item semantic key, independently of
translated names. The importer resolves raw mail records, and the actual
script runner supports gift mail and all five delivery results. Both retail
pointer widths follow the primary cartridge disassemblies:
[Gold](https://github.com/pret/pokegold/blob/master/engine/overworld/scripting.asm)
and [Crystal](https://github.com/pret/pokecrystal/blob/master/engine/overworld/scripting.asm).

Native bag/party/PC menus support composition, reading, detachment and
mailbox attachment. Cancelling composition consumes nothing; an exchange
which cannot return the previous item leaves the inventory and letter
unchanged. Destroying a message requires an explicit default-No choice.

The public `mail.written` event identifies `compose` or `script`, with the
actual entry, carrier, slot, message and author. `mail.read` carries the
entry, message, author and displayed lines once per opening. These native
capabilities are advertised only for generation 2.

The two focused suites exercise 343 checks through production modules,
native menu input, the save codec, public SDK, actual coroutine runner and
synthetic binary ROM decoding. Full quick-tier and packaged GPU acceptance
must be recorded separately against their exact source commits.

This is functional PC/mail groundwork, not complete Gen1 engine parity.
ROM stationery artwork, SRAM mail conversion, complete legacy PC modes,
all story paths and Windows hardware acceptance remain open. No private
mod, cartridge data or generated art is included in this change.

The exact composed `6004286e` Windows/macOS preview is qualified on all four
runtime platforms. Mac ARM with the unchanged supplied Johto package and
actual Crystal passes 68 checks per OpenGL/Metal backend in selected First
and Third Person. This includes an imported PC-special operand lowered by
the real VM, native boot-menu admission and one script resumption, actual
provider transfers/refusals, summary/dex, the player-PC mailbox, composition,
reading and a save-codec round trip. Eight fresh OS-window images were
inspected. See the [source-bound receipt](qa/native-foundation/johto-native-pc-mail.json).

Only the own QA window is activated. Background Metal presentation is not
accepted, and its deprecation overlay partly obscures the second mail line.
Raw/truncated PC item labels, large provider margins and native grayscale
fallback art remain visible. These focused runs do not requalify every
previous battle/map/follower scenario or establish a complete playthrough.
The existing `native-preview-20261025.1` assets were refreshed in place;
the manifest identifies the new binary source while the original tag stays.
