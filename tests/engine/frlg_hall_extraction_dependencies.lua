-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Loader=require('compat.gen1-rs.Loader')
local GV=require('src.core.GameVersion');local saved=love.filesystem.load
love.filesystem.load=function(path)return loadfile(path)end
for _,version in ipairs{'firered','leafgreen'}do
 local bindings={['src.core.GameVersion']=GV,__package={loaded={}}}
 local load=Loader.new(version,bindings);local V=load('src.import.gba.versions_frlg');V.select(version)
 bindings['src.import.gba.versions']=V
 local expected=require('src.import.Gen3FrlgPresentation').TEXT_WINDOWS[version]
 T.eq(V.address(0x471DEC),expected.palette,'own edition palette agrees with independently verified ELF metadata')
 T.eq(V.address(0x41F1C8),expected.message,'own edition dialogue graphic agrees with independent metadata')
 T.eq(V.address(0x471A4C),expected.standard,'own edition standard window agrees with independent metadata')
 T.eq(type(load('src.import.gba.league_extract').run),'function','original Hall extractor dependencies load before ROM work')
 T.eq(type(load('src.import.gba.text_chrome_extract').extractLatinNormal),'function','original font extractor dependencies load')
 local labels=require('src.import.gba.text_labels.'..version)
 for _,key in ipairs(require('src.import.Gen3FrlgHallAssets').LABELS)do
  T.eq(V.NAMED_TEXTS[key],labels[key],'relocated original label agrees with host edition catalog: '..key)
 end
 local songs=load('src.core.game3.constants.firered.songs').byName
 T.eq(songs.SE_APPLAUSE,98,'original FR/LG applause enum loads')
 T.eq(songs.MUS_HALL_OF_FAME,286,'original FR/LG Hall enum loads')
end
love.filesystem.load=saved
T.finish('original FRLG extraction dependencies and independent edition address agreement')
