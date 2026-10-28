package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Loader=require('compat.gen1-rs.Loader')
local savedVersion,savedLoader=V.get(),Loader.new
local savedMusic=package.loaded['src.core.Music']
local savedSynth=package.loaded['src.core.M4ASynth']
local savedPlayer=package.loaded['src.core.NativeCryPlayer']
local savedAudio=love.audio
package.loaded['src.core.Music']={nativeCryStarted=function()end,nativeCryStopped=function()end}
package.loaded['src.core.M4ASynth']={renderNativeCry=function()return {},{frames=3}end}
package.loaded['src.core.NativeCryPlayer']=nil
local Sound=require('src.core.Sound')
local Player=require('src.core.NativeCryPlayer')
local bound
Loader.new=function(_,bindings)
  bound=bindings['src.core.game3.audio']
  return function(name)
    if name=='src.ui.game3.chrome'then return {setFrameType=function()end}end
    if name=='src.core.game3.rng'then return {SeedRng=function()end}end
    assert(name=='src.core.game3.profiles.rs.font',name)
    return {}
  end
end
local Context=require('src.ui.Gen3RsSceneContext')
for _,version in ipairs{'ruby','sapphire'}do
  V.set(version)
  local data={pokemon={CHARMANDER={index=4}},constants={speciesOrder={[4]='CHARMANDER'},
    gen3RsBirch={},gen3RsPresentation={songIds={}}},
    audio={gen3={},gen3Cries={table=0},cries={CHARMANDER={m4a=3}}}}
  local context=Context.new({data=data,save={options={}}})
  local sources={}
  love.audio={newSource=function()
    local source={playing=true,setVolume=function()end,play=function()end}
    function source:isPlaying()return self.playing end
    function source:stop()self.playing=false end
    sources[#sources+1]=source
    return source
  end}
  Sound.stopCry()
  T.eq(bound.isCryFinished(),true,'idle scene has no pending native cry')
  local source=bound.playCry(4)
  T.eq(source,sources[1],'scene returns the actual Sound source')
  T.eq(context.cry,source,'scene retains its source for presentation ownership')
  T.eq(bound.isCryFinished(),false,'a new native recording blocks the scene')
  local before=Player.snapshot()
  for _=1,100 do T.eq(bound.isCryFinished(),false,'polling cannot advance the audio clock')end
  T.same(Player.snapshot(),before,'queries retain native audio duration and clock')
  for _=1,2 do Sound.updateCry()end
  T.eq(bound.isCryFinished(),false,'scene preserves the whole native duration')
  Sound.updateCry()
  T.eq(source:isPlaying(),true,'fixture reproduces a device still reporting playback')
  T.eq(bound.isCryFinished(),true,'native duration releases the real scene despite the device')
  source=bound.playCry(4);source:stop()
  T.eq(bound.isCryFinished(),true,'early source completion retains the native player policy')
  love.audio=nil
  T.eq(bound.playCry(4),nil,'unavailable output device returns no source')
  T.eq(bound.isCryFinished(),false,'device absence still waits for native recording duration')
  for _=1,3 do Sound.updateCry()end
  T.eq(bound.isCryFinished(),true,'headless native recording completes on the audio clock')
  data.audio.gen3=nil
  T.eq(bound.playCry(4),nil,'missing recording pack remains silent')
  for _=1,63 do Sound.updateCry()end
  T.eq(bound.isCryFinished(),false,'no-pack playback retains the native fallback duration')
  Sound.updateCry()
  T.eq(bound.isCryFinished(),true,'the existing native no-pack fallback releases the scene')
  love.audio={newSource=function()error('not used for a native override')end}
  local replacement={playing=true,isPlaying=function(self)return self.playing end,stop=function(self)self.playing=false end}
  data.audio.gen3={};data.audio.cries.CHARMANDER=false
  local oldLegacy=Sound.playCry
  -- Retain the actual native override owner and its device-based completion.
  Sound.playCry=function(d,id)
    return Player.play(d,id,{},function()return replacement end,1,false)
  end
  T.eq(bound.playCry(4),replacement,'scene retains a replacement cry source')
  for _=1,100 do Sound.updateCry()end
  T.eq(bound.isCryFinished(),false,'a replacement cry keeps its own native completion policy')
  replacement.playing=false
  T.eq(bound.isCryFinished(),true,'replacement completion releases the scene')
  Sound.playCry=oldLegacy
  T.check(not pcall(bound.playCry,999),'unknown native species still fail at admission')
  Sound.stopCry()
end
V.set('gold')
T.check(not pcall(Context.new,{data={},save={options={}}}),'Gen2 never enters the RS scene bridge')
Loader.new=savedLoader;love.audio=savedAudio;V.set(savedVersion)
package.loaded['src.core.Music']=savedMusic
package.loaded['src.core.M4ASynth']=savedSynth
package.loaded['src.core.NativeCryPlayer']=savedPlayer
T.finish('RS scenes follow native cry completion and retain device/override ownership')
