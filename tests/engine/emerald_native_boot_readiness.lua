package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local M=require('src.import.Gen3EmeraldPresentation');local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter');local oldRead,oldExists=Fs.read,Fs.exists
local paths={'data/generated/gba/title/manifest.lua','data/generated/gba/intro/rse/manifest.lua',
  'data/generated/gba/intro/rse_extra/manifest.lua','data/generated/gba/intro/rse/scenery/manifest.lua'}
local files={};for _,path in ipairs(paths)do
  files[path]={game='emerald',format=1,files={path..'.png'}}
end
local spec={version='emerald',format=1,songIds={MUS_INTRO=1,MUS_INTRO_BATTLE=2,MUS_TITLE=3},
  speciesIds={SPECIES_GROUDON=4,SPECIES_KYOGRE=5}}
files['data/generated/constants.lua']={gen3EmeraldPresentation=spec}
Fs.read=function(path)return files[path]and Writer.encode(files[path])end
Fs.exists=function()return true end
T.eq(#M.missing(),0,'complete native Emerald boot cache')
files[paths[1]].game='ruby';T.eq(M.missing()[1],paths[1],'Ruby title cannot satisfy Emerald')
files[paths[1]].game='emerald';files[paths[2]].format=2
T.eq(M.missing()[1],paths[2],'unknown cache format fails closed');files[paths[2]].format=1
Fs.exists=function(path)return path~=paths[3]..'.png'end
T.eq(M.missing()[1],paths[3]..'.png','missing extra scene art requires import')
Fs.exists=function()return true end
spec.songIds.MUS_TITLE=nil;T.eq(M.missing()[1],'<emerald:native-boot-identities>','title music identity is required')
spec.songIds.MUS_TITLE=3;spec.speciesIds.SPECIES_KYOGRE=nil
T.eq(#M.missing(),1,'legendary cry identity is required');spec.speciesIds.SPECIES_KYOGRE=5
spec.version='sapphire';T.eq(#M.missing(),1,'wrong cartridge identity is refused');spec.version='emerald'
for _,value in ipairs({true,7,'invalid'})do
 files['data/generated/constants.lua'].gen3EmeraldPresentation=value
 T.eq(#M.missing(),1,'malformed constants fail readiness without raising')
end
Fs.read=function()return 'not valid Lua'end
T.eq(#M.missing(),5,'unreadable manifests and metadata remain missing')
Fs.read,Fs.exists=oldRead,oldExists
T.finish('Emerald native boot cache readiness')
