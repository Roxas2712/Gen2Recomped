-- Metadata shared by external cartridge backends; no GameVersion.set calls.
local M={}
function M.info(version)
 if version=='pinballgbc'then return {generation=2,displayName='Pokémon Pinball',importable=true,external=true,experimental=true}end
 if version=='pinballrs'then return {generation=3,displayName='Pokémon Pinball: Ruby & Sapphire',importable=true,external=true,experimental=true}end
 return require('src.import.LauncherPokemonXY').info(version)
end
function M.versions(console,series)
 local list=require('src.import.LauncherPokemonXY').versions(console,series)
 if (not console or console=='gbc')and(not series or series=='pokemon')then list[#list+1]='pinballgbc'end
 if (not console or console=='gba')and(not series or series=='pokemon')then list[#list+1]='pinballrs'end
 return list
end
return M
