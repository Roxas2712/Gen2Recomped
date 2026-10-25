-- Curated references only; image bytes are downloaded to this device solely
-- after the player explicitly confirms the source and rights notice.
-- Edition/file names checked against Bulbagarden Archives on 2026-10-25.
local Sources={}
local files={
  red='Pokemon_Red_cartridge.png',blue='Pokemon_Blue_cartridge.png',yellow='Pokemon_Yellow_cartridge.png',
  gold='Pokemon_Gold_cartridge.png',silver='Pokemon_Silver_cartridge.png',crystal='Pokemon_Crystal_cartridge.png',
  firered='PokemonFireRedCartridge.png',emerald='Pokemon_Emerald_cartridge.png',
  platinum='Pokémon_Platinum_Cartridge.png',heartgold='Pokémon_HeartGold_Cartridge.png',
  soulsilver='Pokemon_SoulSilver_cartridge.png',black='Pokemon_Black_cartridge.png',white='Pokémon_White_Cartridge.png',
}
local directories={red='1/11',blue='7/7a',yellow='e/e4',gold='2/2e',silver='a/ac',crystal='9/94',firered='6/68',emerald='c/cd',platinum='1/1b',heartgold='1/16',soulsilver='4/4f',black='1/18',white='9/94'}
function Sources.get(version)
  local file=files[version];if not file then return nil end
  local encoded=file:gsub('[^%w_.%-]',function(c) return ('%%%02X'):format(c:byte()) end)
  return {page='https://archives.bulbagarden.net/wiki/File:'..encoded,
    image='https://archives.bulbagarden.net/media/upload/'..directories[version]..'/'..encoded,
    publisher='Bulbagarden Archives',checked='2026-10-25',
    note='Source provides cartridge images under a fair-use claim. Review the source usage terms; this is not a reuse license.'}
end
return Sources
