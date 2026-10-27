# Native indexed battle text colours

The public chrome query returns a font colour record (`fg`, `shadow`, transparent
`bg`) for each indexed foreground/shadow pair. Numeric foreground aliases and
the second shadow return preserve existing tuple callers. No-argument queries
retain the native message role. Records are detached and follow live palette,
dataset and edition changes; invalid indices fail before drawing.

RS uses its already imported, edition-bound palette. The validated FR/LG and
Emerald textbox stage now retains all sixteen first-bank BGR555 words rather
than discarding them after composing images. Only those three import cache
markers gain `gba-textbox-palette-v1`; player save formats are unchanged. Older
role-only data can answer its exact named indices. Unavailable arbitrary pairs
return the existing white font fallback with a diagnostic, never numeric font
options or fabricated palette entries.

Fork frozen source `a9c30f1ace` passes 43 groups, including 10,490 indexed-colour,
real proportional-font and owner-isolation checks, 78 real extraction/cache
checks and 315 existing chrome checks. The older public composition
`f35174ef21` passes 27 groups, including the same two new contract groups.
Its test uses the existing readiness marker closure where the later pure cache
descriptor is unavailable; no new unrelated production API is added.

The subsequent unchanged-adapter CPU audit passes the text-colour boundary.
Full game, cartridge artwork, window appearance and sustained FPS acceptance
remain separate. Reference mods and player profiles were untouched; managed QA
retains at least 20 GiB free.
