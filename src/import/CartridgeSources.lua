-- Reference pages only. Images are neither bundled, fetched, cached, nor
-- uploaded by RetroRecomped. The player opens the page and saves a file.
-- Edition/file names checked against Bulbagarden Archives on 2026-10-25.
local Sources={}
local files={
  red='Pokemon_Red_cartridge.png',blue='Pokemon_Blue_cartridge.png',yellow='Pokemon_Yellow_cartridge.png',
  gold='Pokemon_Gold_cartridge.png',silver='Pokemon_Silver_cartridge.png',crystal='Pokemon_Crystal_cartridge.png',
  firered='PokemonFireRedCartridge.png',emerald='Pokemon_Emerald_cartridge.png',
  platinum='Pokémon_Platinum_Cartridge.png',heartgold='Pokémon_HeartGold_Cartridge.png',
  soulsilver='Pokemon_SoulSilver_cartridge.png',black='Pokemon_Black_cartridge.png',white='Pokémon_White_Cartridge.png',
}
function Sources.get(version)
  local file=files[version];if not file then return nil end
  local encoded=file:gsub('[^%w_.%-]',function(c) return ('%%%02X'):format(c:byte()) end)
  return {page='https://archives.bulbagarden.net/wiki/File:'..encoded,
    publisher='Bulbagarden Archives',checked='2026-10-25',
    note='Source provides cartridge images under a fair-use claim. Review the source usage terms; this is not a reuse license.'}
end
return Sources
