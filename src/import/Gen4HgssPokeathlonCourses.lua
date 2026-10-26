-- gen4_hgss_pokeathlon: the Pokeathlon course tables (see Gen4HgssPokeathlon).
return { build = function(x) return require("src.import.Gen4HgssPokeathlon").courses(x.rom) end }
