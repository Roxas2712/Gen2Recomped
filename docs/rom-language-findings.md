# Original-source language regressions

This extends the native `rom-language-v1` implementation; no mod-side
conversion backend is loaded or packaged.

Expanded PT-BR FireRed/LeafGreen records use 44 bytes, category length 20,
and text pointers at +24/+28. `gba_dex.lua` respects the profile fields and
participates in the compiled-cache fingerprint. Source acceptance checks
read all 386 national entries and both pointer fields in each cartridge.
An empty second page is valid source data and is preserved.

Battle ability display names now come from the localized native ability
records. The actual local callers pass the dataset, so changing an exported
helper without affecting its local callers is avoided. Stat arguments go
through the original caption catalog; explicit GBA stat IDs resolve source
spellings such as SP. ATK versus the engine's SPCL.ATK. Neither mechanic IDs,
stage arithmetic, weather nor nicknames are rewritten.

The old host UI fallback table authored labels absent from the cartridge
catalog, including an incorrect alternative for German GSC LEVEL UP.
Only existing captions and explicit original source labels are now reused.
English restoration accepts the absence of both a compiled result and a
string catalog, without inventing an English baseline catalog.

Focused validation:

```
python3 tools/check_language_findings.py --focused --luajit /path/to/luajit \
  --mod /path/to/uni-language-ascendant --imports /path/to/private/baseroms
```

This runs the native protocol, import publication, LOVE file API and move
effect regressions plus actual PT-BR source checks. Omit `--focused` for the
full engine suite as well. These are scoped source/runtime checks, not full
playthroughs or certification of every language and screen. Shared German
caption fixes and the complete retained source index are contributed in the
Uni-Language Ascendant repository.
