package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Loader=require('compat.gen1-rs.Loader')
local Bridge=require('src.import.Gen3RsPresentation')
local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter')
local originalLove=love
love={filesystem={load=loadfile}}
local ruby,sapphire=Loader.new('ruby'),Loader.new('sapphire')
local a,b=ruby('src.core.game3.rng'),sapphire('src.core.game3.rng')
a.SeedRng(42);b.SeedRng(42)
local expected=b.Random();b.SeedRng(42)
T.eq(a.Random(),expected,'same native seed gives same presentation randomness')
a.Random();a.Random()
T.eq(b.Random(),expected,'one movie never advances another edition RNG')
T.eq(package.loaded['src.core.game3.rng'],nil,'reference RNG never enters host module cache')
local ar=ruby('src.import.gba.syms').of('ruby')
local bs=sapphire('src.import.gba.syms').of('sapphire')
T.check(ar.off('mus_title')~=bs.off('mus_title'),'title songs use distinct native ROM addresses')
T.check(not pcall(Loader.new,'emerald'),'Emerald cannot select an RS reference')
local oldRead,oldExists=Fs.read,Fs.exists
local bodies,files={},{}
local manifests={'data/generated/gba/title/manifest.lua',
  'data/generated/gba/intro/rs/manifest.lua','data/generated/gba/intro/rs/scenery/manifest.lua'}
for i,path in ipairs(manifests) do
  local image='data/generated/gba/test/'..i..'.png'
  bodies[path]=Writer.encode({format=1,layout='rs',game='sapphire',files={image}})
  files[image]=true
end
Fs.read=function(path) return bodies[path] end
Fs.exists=function(path) return files[path] end
T.eq(#Bridge.missing('sapphire'),0,'complete own-edition movie/title is ready')
T.eq(#Bridge.missing('ruby'),3,'another edition cannot satisfy native cache contract')
files['data/generated/gba/test/1.png']=nil
T.eq(Bridge.missing('sapphire')[1],'data/generated/gba/test/1.png','lost title art invalidates completed cache')
bodies[manifests[2]]='return {layout="rs",game="sapphire",files={}}'
T.eq(#Bridge.missing('sapphire'),2,'empty movie manifest cannot pass after interrupted import')
bodies[manifests[3]]='broken Lua source'
T.eq(#Bridge.missing('sapphire'),3,'invalid manifest is reported without running it')
local called=false
Bridge.extract({version='leafgreen',beginStage=function()called=true end})
T.eq(called,false,'LeafGreen never enters RS import')
Fs.read,Fs.exists=oldRead,oldExists
love=originalLove
T.finish('Native RS presentation boundaries and damaged-cache detection')
