-- Metadata shared by external cartridge backends; no GameVersion.set calls.
local M={}
function M.info(version)
 if version=='pinballrs'then return {generation=3,displayName='Pokémon Pinball: Ruby & Sapphire',importable=true,external=true}end
 return require('src.import.LauncherPokemonXY').info(version)
end
function M.versions(console,series)
 local list=require('src.import.LauncherPokemonXY').versions(console,series)
 if (not console or console=='gba')and(not series or series=='pokemon')and require('src.import.LauncherPinball').available()then list[#list+1]='pinballrs'end
 return list
end
return M
