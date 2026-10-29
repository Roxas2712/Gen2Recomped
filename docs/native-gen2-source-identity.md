# Source GSC gene identity API on the older native host

Prepared on offered PR401/current original main8d5b4387, retaining its actual
older RNG constructor and native owners. Source vanillaShiny/isShiny take
the gene table, vanillaGender/gender take definition then genes, and
randomDVs draws four native genes with HP derived at the later source birth
boundary. Native births/reads use those same GSC hook/predicate owners;
no extra Pokemon, simulator or RNG stream is introduced. GBA PID and cached/
forced native identity remain under their existing owners.

The newer c38d06a6 candidate passes262168pure-data/450actual SDK/native checks,
plus its existing identity, appearance, PP and stat groups. These do not
qualify this older combined host. Its copied source-signature fixtures and
existing native identity/field/stat/PP regressions await their own execution.
The source options-record constructor, remaining Mon and standalone battle/
turn/event APIs, full visuals and final packaged release remain open.

Integration/tests by Roxas2712 are offered under
https://github.com/Roxas2712/Gen2Recomped/blob/main/LICENSE-ROXAS2712.md,
including its specific Cedric / UNDERdecoded permission with visible credit.
Existing authors' rights, provenance, notices and earlier grants remain.
