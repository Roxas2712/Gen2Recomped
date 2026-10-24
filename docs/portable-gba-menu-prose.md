# Portable native GBA menu prose

`mod.content.rom_text` now reaches the registered FireRed/Emerald party action
readers and their separate cancel buttons. FireRed's actual Item-PC withdrawal
flow also reads overrides for its title, cancel list row and three submenu labels.
The same public consumer runs on both engines; no renderer replacement or engine
module import is needed. See `examples/portable_gba_menu_prose`.

| Action | FireRed label | Emerald label |
| --- | --- | --- |
| SUMMARY | `sCursorOptions[0]` | `gText_Summary5` |
| SWITCH | `sCursorOptions[1]` | `gText_Switch2` |
| CANCEL action | `sCursorOptions[2]` | `gText_Cancel2` |
| ITEM | `sCursorOptions[3]` | `gText_Item` |
| GIVE | `sCursorOptions[4]` | `gMenuText_Give` |
| TAKE | `sCursorOptions[5]` | `gText_Take` |
| SHIFT | `sCursorOptions[10]` | `gText_Shift` |
| SEND OUT | `sCursorOptions[11]` | `gText_SendOut` |
| ENTER | `sCursorOptions[12]` | `gText_Enter` |
| NO ENTRY | `sCursorOptions[13]` | `gText_NoEntry` |
| STORE | `sCursorOptions[14]` | `gText_Store` |
| Party cancel button | `gFameCheckerText_Cancel` | `gText_Cancel` |

FireRed's Item-PC title is `gText_WithdrawItem`; its submenu reads
`gText_Withdraw`, `gOtherText_Give` and `gFameCheckerText_Cancel`. The last label
is intentionally shared with the party button, matching the reference reader.
Emerald's `gText_Take2` is a separate label; overriding it does not replace the
primary TAKE action. Unmapped roles do not borrow a label just because their
English fallback happens to match. A custom/TOSS title retains its own text.

Unmodified and removed overrides keep native imported labels or the existing
older-cache/`strings` fallback. Empty strings remain empty. Reads leave imported
constants untouched. Menu action identities and input behavior are independent
of translated label text. Source controls are printed through the existing
shared source-string conversion and native textbox token expansion.

The contracts compare real reference action producers and captured native font
output for the party cancel button and FireRed Item PC. Emerald's generated
manifest fixture exercises the actual profile-specific branch. Separate host
tests exercise battle/order/item action construction, native submenu rendering,
selection identities, custom-title isolation and older-cache fallback.
Run `tools/gba-menu-prose-contract-check/check.py` as described in its README.

This does not bind every party prompt, field-move name, mail/trade message,
Item-PC quantity/result dialog or battle message. Emerald's different Item-PC
screen and DS screens remain separate work. Text binding is not pixel/layout,
complete-playthrough or universal printer equivalence.
