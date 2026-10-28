-- Curated references only; image bytes are downloaded to this device solely
-- after the player explicitly confirms the source and rights notice.
-- Edition/file names checked against Bulbagarden Archives on 2026-10-25.
local Sources={EXTERNAL_ORDER={'x','y','pinballrs'}}
local hosted=require('src.import.CartridgeImages')
local files={
  red='Pokemon_Red_cartridge.png',blue='Pokemon_Blue_cartridge.png',yellow='Pokemon_Yellow_cartridge.png',
  gold='Pokemon_Gold_cartridge.png',silver='Pokemon_Silver_cartridge.png',crystal='Pokemon_Crystal_cartridge.png',
  firered='PokemonFireRedCartridge.png',emerald='Pokemon_Emerald_cartridge.png',
  leafgreen='Pokemon_LeafGreen_Cartridge.png',ruby='Pokemon_Ruby_cartridge.png',sapphire='Pokemon_Sapphire_cartridge.png',
  platinum='Pokémon_Platinum_Cartridge.png',heartgold='Pokémon_HeartGold_Cartridge.png',
  soulsilver='Pokemon_SoulSilver_cartridge.png',black='Pokemon_Black_cartridge.png',white='Pokémon_White_Cartridge.png',
  x='Pokémon_X_Cartridge.png',y='Pokemon_Y_cartridge.png',pinballrs='Pokemon_Pinball_Ruby_and_Sapphire_cartridge.png',
}
local directories={red='1/11',blue='7/7a',yellow='e/e4',gold='2/2e',silver='a/ac',crystal='9/94',firered='6/68',emerald='c/cd',platinum='1/1b',heartgold='1/16',soulsilver='4/4f',black='1/18',white='9/94'}
directories.leafgreen='9/9a';directories.ruby='0/0e';directories.sapphire='2/28'
directories.x='3/3d';directories.y='c/c3';directories.pinballrs='9/94'
function Sources.get(version)
  local file=files[version];if not file then return nil end
  local encoded=file:gsub('[^%w_.%-]',function(c) return ('%%%02X'):format(c:byte()) end)
  local asset=hosted[version]
  return {page='https://archives.bulbagarden.net/wiki/File:'..encoded,
    image=asset and ('https://pokexpert.de/api/cloud/v1/cartridges/'..version) or ('https://archives.bulbagarden.net/media/upload/'..directories[version]..'/'..encoded),
    originalImage='https://archives.bulbagarden.net/media/upload/'..directories[version]..'/'..encoded,
    sha256=asset and asset.sha256,bytes=asset and asset.bytes,width=asset and asset.width,height=asset and asset.height,
    credit=asset and asset.credit,delivery=asset and 'ModCompass · pokexpert.de' or 'Bulbagarden Archives',
    publisher='Bulbagarden Archives',checked='2026-10-25',
    note='Source provides cartridge images under a fair-use claim. Review the source usage terms; this is not a reuse license.'}
end
return Sources
