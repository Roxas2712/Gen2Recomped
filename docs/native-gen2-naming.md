# Native Gen2 naming owner

`Gen2NamingScreen` now owns Gen2 entry state, input and presentation rather
than adapting the Gen1 keyboard. The zero-based cursor addresses four letter
rows (five for a box) and a bottom row of CASE, DEL and END targets. SELECT
changes case, B deletes a complete font glyph, START selects END, and A on END
accepts. Filling the field also selects END and waits for confirmation. Spaces
are actual cells. Unicode and charmap ligatures occupy complete name slots.

The public constructor preserves caller-owned dismissal. The ordinary
`NamingScreen` constructor delegates to this same native owner on Gen2 while
preserving its existing pop-before-callback convention. Native scripts,
catches and Oak therefore use the real Gen2 model. Other generations retain
their existing constructors. Screen registry overrides remain authoritative.
The `src.ui.gen2.NamingScreen` class spelling resolves to this owner, so external
presenters can observe and draw its actual rows, cursor, text and field size.

Name presets temporarily make the naming screen transparent and suppress its
keyboard until NEW NAME is chosen; the original parent remains underneath.
Native imported sprite and optional menu-art records can supply the header,
backdrop and retained cursor quads. Mail entry keeps both sixteen-glyph rows
above its keyboard. Native Oak and rival/name-rater calls carry their actual
player/rival/Pokemon role instead of inferring it from a field length. Default board data is an engine fallback; a `data.gen2Naming` record
can supply normal/box upper/lower rows. `ui.naming.grid` retains its public
context and can replace those rows.

Font aliases for `<PK>`, `<MN>` and `<DOT>` resolve only to sequences actually
present in the active font. They neither assume retail glyph ordinals nor
replace explicitly authored aliases. Measurements, editing and drawing use
that same charmap.

ROM-free tests cover actual stack/menu input, name types and glyph limits,
caller/native completion ownership, preset underlay suppression, Gen1
retention and actual Loader clients through native API1/2 and unified API2/3.
GPU acceptance and full reference raster/helper parity remain separate:
ROM naming-program/menu-art extraction, exact cursor/header rendering and the
separate Gen2 NamePick portrait animation are still open. This change does not
establish complete VASC, naming-story, save/link or full Gen1 parity.
