-- Exact native Emerald boot assets from the pinned Gen1Recomp bridge.
local Bridge={}
local paths={'data/generated/gba/title/manifest.lua',
  'data/generated/gba/intro/rse/manifest.lua',
  'data/generated/gba/intro/rse_extra/manifest.lua',
  'data/generated/gba/intro/rse/scenery/manifest.lua'}

local function read(path)
  local raw=require('src.import.CacheFs').read(path)
  local f=raw and loadstring(raw,'@'..path)
  if not f then return end
  setfenv(f,{})
  local ok,value=pcall(f)
  if ok and type(value)=='table'then return value end
end

function Bridge.missing()
  local Fs=require('src.import.CacheFs');local absent={}
  for _,path in ipairs(paths)do
    local m=read(path)
    if not m or m.game~='emerald'or m.format~=1
      or type(m.files)~='table'or #m.files==0 then
      absent[#absent+1]=path
    else
      for _,file in ipairs(m.files)do
        if type(file)~='string'or not Fs.exists(file)then absent[#absent+1]=tostring(file)end
      end
    end
  end
  local c=read('data/generated/constants.lua')
  local s=c and c.gen3EmeraldPresentation
  if type(s)~='table'or s.version~='emerald'or s.format~=1 or type(s.songIds)~='table'
    or not s.songIds.MUS_INTRO or not s.songIds.MUS_INTRO_BATTLE or not s.songIds.MUS_TITLE
    or type(s.speciesIds)~='table'or not s.speciesIds.SPECIES_GROUDON or not s.speciesIds.SPECIES_KYOGRE then
    absent[#absent+1]='<emerald:native-boot-identities>'
  end
  return absent
end

function Bridge.extract(extractor)
  if extractor.version~='emerald'then return end
  extractor:beginStage('Emerald native intro and title')
  local expected=require('src.core.GameVersion').info('emerald').sha1
  assert(love.data.encode('string','hex',love.data.hash('sha1',extractor.rom.data))==expected,
    'Emerald native presentation cartridge mismatch')
  local load=require('compat.gen1-rs.Loader').new('emerald',{__package={loaded={}}})
  local rom={id='emerald'}
  function rom:get(off)return extractor.rom:u8(off)end
  function rom:u16(off)return extractor.rom:u16(off)end
  function rom:u32(off)return extractor.rom:u32(off)end
  function rom:readString(off,size)
    assert(off>=0 and off+size<=extractor.rom.size,'Emerald resource outside cartridge')
    return extractor.rom.data:sub(off+1,off+size)
  end
  local cache={}
  function cache:write(path,bytes)
    local ok,why=require('src.import.CacheFs').write(path,bytes)
    assert(ok,'Could not write native Emerald boot: '..tostring(why));return true
  end
  for _,name in ipairs({'extract_title_rse','intro_credits_gfx_extract',
    'extract_intro_emerald','extract_intro_extra_emerald'})do
    assert(load('src.import.gba.rse.'..name).run(rom,cache,{game='emerald'}))
  end
  local songs=load('src.core.game3.constants.emerald.songs').byName
  local species=load('src.core.game3.constants.emerald.species').byName
  local constants=assert(extractor._constants)
  constants.gen3EmeraldPresentation={version='emerald',format=1,songIds=songs,
    speciesIds={SPECIES_GROUDON=assert(species.SPECIES_GROUDON),SPECIES_KYOGRE=assert(species.SPECIES_KYOGRE)},
    title=paths[1],intro=paths[2]}
  local audio=assert(extractor._audio)
  audio.special=audio.special or {}
  for role,name in pairs({intro='MUS_INTRO',introBattle='MUS_INTRO_BATTLE',title='MUS_TITLE'})do
    local id=('SONG_%03X'):format(assert(songs[name]))
    assert(extractor._songs[id],'Missing native Emerald music '..name)
    audio.special[role]=id
  end
  extractor:write('constants',constants);extractor:write('audio',audio)
  assert(#Bridge.missing()==0,'Native Emerald boot was not fully written')
  require('src.core.Logger').info('Emerald native movie/title and edition-specific song identities extracted')
end
return Bridge
