-- The original RS boot screens need their own graphics and song identities.
-- No Emerald scenes, song numbers or ROM payloads are substituted here.
local Bridge = {}
local Loader = require('compat.gen1-rs.Loader')

function Bridge.extract(extractor)
  local version = extractor.version
  if version ~= 'ruby' and version ~= 'sapphire' then return end
  extractor:beginStage('Ruby/Sapphire intro, title and music')
  local load = Loader.new(version)
  local S = load('src.import.gba.syms').of(version)
  local rom = { id = version }
  function rom:get(off) return extractor.rom:u8(off) end
  function rom:u16(off) return extractor.rom:u16(off) end
  function rom:u32(off) return extractor.rom:u32(off) end
  function rom:readString(off, size)
    assert(off >= 0 and off + size <= extractor.rom.size, 'RS resource outside cartridge')
    return extractor.rom.data:sub(off + 1, off + size)
  end
  -- The top-level importer has already verified this exact cartridge hash.
  -- The reference symbol maps are selected independently for each edition.
  local expected = require('src.core.GameVersion').info(version).sha1
  assert(love.data.encode('string', 'hex', love.data.hash('sha1', extractor.rom.data)) == expected,
    'RS presentation cartridge mismatch')
  local cache = {}
  function cache:write(path, bytes)
    local ok, why = require('src.import.CacheFs').write(path, bytes)
    assert(ok, 'Could not write RS presentation: '..tostring(why))
    return true
  end
  for _, name in ipairs({'extract_title', 'extract_intro_scenery', 'extract_intro'}) do
    assert(load('src.import.gba.rs.'..name).run(rom, cache))
  end
  require('src.import.Gen3RsBag').extract(extractor, load, rom, cache)
  require('src.import.Gen3RsSummaryAssets').extract(extractor, load, rom, cache)
  require('src.import.Gen3RsPartyAssets').extract(extractor, load, rom, cache)
  require('src.import.Gen3RsMapData').presentation(extractor,load,rom,cache)
  require('src.import.Gen3RsBirchAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsMainMenuAssets').extract(extractor,load,rom)
  require('src.import.Gen3RsStartMenuFlags').extract(extractor,load)
  require('src.import.Gen3RsStarterAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsBattlePanelAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsHealthboxAssets').extract(extractor,load,rom,cache)
  local positions=extractor._constants.gen3BattlerCoords
  assert(positions and positions.singles and #positions.singles==4
    and positions.doubles and #positions.doubles==4,'RS native battler positions absent')
  require('src.import.Gen3RsPokenavAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsStorageAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsPokedexAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsShopAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsBikeSprites').extract(extractor)
  require('src.import.Gen3RsWhiteout').extract(extractor)
  require('src.import.Gen3RsClockAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsBerryTagAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsSaveAssets').extract(extractor,load,rom)
  require('src.import.Gen3RsItemPcAssets').extract(extractor,load,rom)
  require('src.import.Gen3RsMailAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsCableCarAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsWeatherAssets').extract(extractor,load,rom,cache)
  require('src.import.Gen3RsCreditsAssets').extract(extractor,load,rom,cache)

  local audio = assert(extractor._audio)
  local songs = assert(extractor._songs)
  local labels, numbers, named = {}, {}, 0
  for label, song in pairs(songs) do
    if type(song) == 'table' and song.header and song.tracks then
      for _, symbol in ipairs(S.namesAt(song.header)) do
        if symbol:match('^mus_') or symbol:match('^se_') then
          local name = symbol:upper()
          labels[name], numbers[name] = label, song.index
          song.musName = name:gsub('^MUS_', '')
          named = named + 1
          if symbol:match('^se_') then
            audio.sfx[name] = { m4a = song.index, song = label }
          end
        end
      end
    end
  end
  local roles = { intro='MUS_INTRO', introBattle='MUS_INTRO_BATTLE', title='MUS_TITLE',
    credits='MUS_CREDITS', hallOfFame='MUS_HALL_OF_FAME', bike='MUS_CYCLING',
    surf='MUS_SURF', evolution='MUS_EVOLUTION' }
  audio.special = audio.special or {}
  for role, name in pairs(roles) do audio.special[role] = assert(labels[name], 'Missing RS song '..name) end
  require('src.battle.Gen3RsBattleMusic').install(audio,labels)
  require('src.battle.Gen3RsBattleMusic').installEffects(audio)
  -- RS has twelve fanfares, so the Emerald fourteen-entry discovery rule
  -- cannot identify this table. Read its own sized symbol and actual IDs.
  local fanfares={}
  local fanfareAt=S.off('sFanfares')
  for row=0,S.count('sFanfares',4)-1 do
    local id=extractor.rom:u16(fanfareAt+row*4)
    local frames=extractor.rom:u16(fanfareAt+row*4+2)
    local label=('SONG_%03X'):format(id)
    local song=assert(songs[label], 'RS fanfare missing from song table')
    assert(song.musName and frames>0 and frames<3600, 'Invalid RS fanfare')
    fanfares[song.musName]={song=label,index=id,frames=frames}
  end
  audio.fanfares=fanfares
  for role,name in pairs({Level_Up='LEVEL_UP',Get_Item1='OBTAIN_ITEM',Get_Item2='OBTAIN_ITEM',
    Get_Key_Item='OBTAIN_ITEM',Heal_HP='HEAL',Slots_Reward='SLOTS_WIN',Wrong='TOO_BAD'}) do
    local fanfare=assert(fanfares[name], 'Missing RS fanfare '..name)
    audio.sfx[role]={m4a=fanfare.index,song=fanfare.song,fanfare=name}
  end
  audio.sfx.NativeRsCaughtIntro={m4a=assert(numbers.MUS_EVOLVED),song=assert(labels.MUS_EVOLVED),fanfare='EVOLVED'}
  audio.sfx.Ball_Toss={m4a=assert(numbers.SE_BALL_THROW),song=assert(labels.SE_BALL_THROW)}
  require('src.import.Gen3RsWallyAssets').extract(extractor,load,rom,cache,numbers)
  audio.songs = songs
  local constants = assert(extractor._constants)
  local nativeNames={}
  for name,index in pairs(numbers)do nativeNames[index]=name:gsub('^MUS_','')end
  constants.gen3SongNames={names=nativeNames,declared=true,
    source='ROM:edition-specific mus_/se_ headers matched to native RS symbols'}
  constants.gen3RsPresentation = {version=version, format=1, songIds=numbers,
    title='data/generated/gba/title/manifest.lua', intro='data/generated/gba/intro/rs/manifest.lua'}
  extractor:write('constants', constants)
  extractor:write('songs', songs)
  extractor:write('audio', audio)
  assert(#Bridge.missing(version)==0, 'Native RS presentation was not fully written')
  require('src.core.Logger').info('RS native intro/title extracted; %d original song identities', named)
end

function Bridge.missing(version)
  local Fs=require('src.import.CacheFs')
  local paths={'data/generated/gba/title/manifest.lua',
    'data/generated/gba/intro/rs/manifest.lua',
    'data/generated/gba/intro/rs/scenery/manifest.lua'}
  local absent={}
  for _,path in ipairs(paths) do
    local raw=Fs.read(path)
    local chunk=raw and loadstring(raw,'@'..path)
    if chunk then setfenv(chunk,{}) end
    local ok,manifest=false,nil
    if chunk then ok,manifest=pcall(chunk) end
    if not ok or type(manifest)~='table' or manifest.layout~='rs'
      or (version and manifest.game~=version)
      or type(manifest.files)~='table' or #manifest.files==0 then
      absent[#absent+1]=path
    else
      for _,file in ipairs(manifest.files) do
        if type(file)~='string' or not Fs.exists(file) then absent[#absent+1]=tostring(file) end
      end
    end
  end
  local raw=Fs.read('data/generated/audio.lua')
  local chunk=raw and loadstring(raw,'@data/generated/audio.lua')
  if chunk then setfenv(chunk,{})end
  local ok,audio=false,nil
  if chunk then ok,audio=pcall(chunk)end
  if not ok or not require('src.battle.Gen3RsBattleMusic').ready(audio)then
    absent[#absent+1]='data/generated/audio.lua'
  end
  raw=Fs.read('data/generated/constants.lua')
  chunk=raw and loadstring(raw,'@data/generated/constants.lua')
  if chunk then setfenv(chunk,{})end
  local constants
  ok,constants=false,nil
  if chunk then ok,constants=pcall(chunk)end
  local flash=ok and type(constants)=='table'and constants.gen3Flash
  if type(flash)~='table'or flash.rsVersion~=version or flash.rsFormat~=1
    or flash.maxLevel~=4 or flash.dark~=4 or flash.lit~=1 or flash.flagNumber~=0x828
    or type(flash.radii)~='table'or #flash.radii~=5 or flash.radii[5]~=24 then
    absent[#absent+1]='<rs:native-flash>'
  end
  local terrain=ok and type(constants)=='table'and constants.gen3Ice and constants.gen3Ice.nativeRsTerrain
  if not require('src.import.Gen3RsTerrain').valid(terrain,version)then
    absent[#absent+1]='<rs:native-terrain-predicates>'
  end
  local crack=ok and type(constants)=='table'and constants.gen3CrackedFloor
  if type(crack)~='table'or crack.floor~=0xD2 or crack.hole~=0x66
    or type(crack.maps)~='table'or type(crack.swap)~='table'then
    absent[#absent+1]='<rs:native-cracked-floor>'
  end
  if not require('src.import.Gen3RsBike').valid(ok and type(constants)=='table'and constants.gen3Bike,version)then
    absent[#absent+1]='<rs:native-bike-rules>'
  end
  local bodies=ok and type(constants)=='table'and constants.gen3RsBikeSprites
  if not require('src.import.Gen3RsBikeSprites').valid(bodies,version)then
    absent[#absent+1]='<rs:native-bike-sprites>'
  else
    for _,path in ipairs(bodies.resources)do if not Fs.exists(path)then absent[#absent+1]=path end end
  end
  local body=Fs.read('data/generated/map_scripts.lua')
  local f=body and loadstring(body)
  if f then setfenv(f,{})end
  local poolOk,pool=false,nil;if f then poolOk,pool=pcall(f)end
  if not require('src.import.Gen3RsWhiteout').valid(ok and type(constants)=='table'and constants.gen3RsWhiteout,
    version,poolOk and pool)then absent[#absent+1]='<rs:native-whiteout-recovery>'end
  for _,path in ipairs(require('src.import.Gen3RsClockAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsBerryTagAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsSaveAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsMainMenuAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsHealthboxAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsItemPcAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsMailAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsCableCarAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsWeatherAssets').missing(version))do absent[#absent+1]=path end
  for _,path in ipairs(require('src.import.Gen3RsCreditsAssets').missing(version))do absent[#absent+1]=path end
  return absent
end

return Bridge
