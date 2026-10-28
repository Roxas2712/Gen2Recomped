# Ruby and Sapphire dialogue identities

An ordinary Ruby run reached the Petalburg Woods ambush with a native
TEAM MAGMA trainer but TEAM AQUA in the dialogue. The ROM header and SHA-1
were Ruby's. The host decoder had interpreted raw placeholder IDs 8–13 as
Emerald's fixed Aqua/Magma, Archie/Maxie and Kyogre/Groudon names.

RS uses those bytes for opposing and allied roles. The import now retains
six semantic tokens and extracts their values, version name and gendered
rival/honorific strings from the selected cartridge. Ruby's opposing roles
resolve to Magma/Maxie/Groudon; Sapphire's resolve to Aqua/Archie/Kyogre.
Explicit literal team names are unchanged. Both the ordinary TextBox and
native named-text expansion read the same detached host constants.
Translated IR retains those role identities and the text registry accepts
the six original semantic placeholders.

The original placeholder extractor is retained byte-for-byte from
Gen1Recomp `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`, with its individual
hash and existing GPLv3/additional terms. No cartridge words are vendored.
`rs-edition-placeholders-v1` requires new RS imports. Readiness rejects
another edition, missing constants and a missing/corrupt or inconsistent
native placeholder file. Other editions retain their existing token maps.

Verification: 106 focused assertions cover the real native extractor over
bounded owned bytes, actual host decoding, role expansion, translation,
gender selection, literal-name preservation and cache isolation. Existing
native prose ownership and formatter suites add 510 and 57 assertions.

Both editions pass fresh full native imports at
`ab36cc2c331070baec450780168ad310d5076ace`. The prepared fixture opens each
edition's actual imported forest text key, checks the opposing team in its
real TextBox pages and final renderer, then verifies all six roles and both
gendered rivals/version names. Four captures per edition, callback once,
field return and draw-time save/RNG immutability pass. This is prepared text
acceptance; the original ordinary Ruby trace remains evidence of the trigger,
not a replay with patched live code.

Integration `81ef4c3791420f2410f54f1382ca16d7a782e08d` preserves public main
`1658cb05c9d095040ea26db4b4f4d8f7609c41fa`, including its native RS options.
The provenance union preserves both byte-exact files and their original hashes.

Five integrated suites pass 859 assertions, including both original RS option
contracts. The final head changes documentation only.
