# Preserve source metatile attributes

The native GBA renderer normalizes FRLG attributes into its own behavior and
layer convention. Compatibility consumers need the original cartridge values:
for example source behavior `0xD1` becomes native `0x5A`, while source `0x11`
becomes native `0x5B`. Unknown ninth-bit behaviors can lose their identity in
that normalization. A reverse conversion cannot reliably recover them.

The importer now writes the original four-byte FRLG attribute words as
`sourceAttributes`, with `sourceAttributeBytes` and `sourceBehaviorMask` on
each bank record. The existing `attributes` and pair collision arrays retain
their native representation. Hoenn's two-byte `attributes` are already exact
source words, so the new metadata refers to those bytes without duplicating
the string or its serialized payload.

`Gen3Tiles:sourceBehavior(metatile)` reads the source numbering across primary
and secondary banks. It returns nil for stale normalized-only metadata,
malformed/truncated source data, invalid IDs and a missing secondary bank.
`attributes()` continues to expose the native behavior and layer unchanged.
The source reader does not alter either record or install itself in rendering
or collision paths.

Registered GBA cache markers gain `source-metatile-attrs-v1:` so old caches
are rebuilt instead of guessed. Other generations' markers and save formats
are unchanged. The composed fork retains the existing Ruby/Sapphire item-menu
marker; this addition composes with the separate cartridge PRs #183/#186/#187.
No player profile is used by these tests, and no old cache is mounted as a new
schema.

Validation is ROM-free and exercises the actual extraction/write boundary,
native attribute reader and new source reader. Synthetic 16/32-bit cartridge
records prove exact source bytes, distinct native values, layers, the ninth
behavior bit, mixed-width banks, missing/truncated records and marker scope.
The independent upstream patch passes 49 checks on its available editions;
the five-edition composed fork passes 57. Replacing the extractor with the
pre-change version makes the same test fail on absent source bytes/metadata.
Twelve relevant composed suites pass, covering terrain animation, render data,
palette refresh, dataset views and all three additional cartridge registrations.
The frozen final composed fork passes 326/326 engine suites and SDK 3/3.
This does not constitute a new real-ROM import, GPU run, or full mod acceptance.

Run `luajit tests/engine/gen3_source_attributes.lua`. These records are a
prerequisite for semantic compatibility views; active map/session binding,
script writes, atlas ownership and unchanged Origami execution remain open.
