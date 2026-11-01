-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local W=require('src.world.Gen3SavedWeather')
local S=require('src.pokemon.Gen3GameStats')
local Gen3Commands=require('src.script.Gen3Commands')
local Commands=require('src.script.Commands')
local Game=require('src.core.Game')
local OW=require('src.world.OverworldController')
local oldVersion,oldSave,oldData=V.get(),Game.save,Game.data
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  for old=0,14 do for new=0,14 do
    local save={gen3Weather=old,gen3WeatherActive=12,gen3Stats={[40]=9},
      party={'owned'},inventory={POTION=3},player={name='OWNED'}}
    local expected=new~=old and(new==3 or new==5)and 10 or 9
    T.eq(W.set(save,new),new,'saved weather keeps its native numeric identity')
    T.eq(S.get(save,40),expected,'only changed saved light/storm rain counts in '..edition)
    T.eq(save.gen3WeatherActive,12,'SetSavedWeather defers the visible weather')
    T.eq(save.party[1],'owned','commit preserves the owned party')
  end end
  local cycle119={2,3,5,3};local cycle123={2,2,3,2}
  for stage=0,7 do
    local save={gen3WeatherStage=stage}
    T.eq(W.resolve(nil,save,20),cycle119[stage%4+1],'native Route119 translation at commit')
    T.eq(W.resolve(nil,save,21),cycle123[stage%4+1],'native Route123 translation at commit')
  end
  local save={gen3Weather=2,gen3WeatherActive=2,gen3WeatherStage=2,gen3Stats={[40]=0},player={map='A'}}
  local data={constants={gen3WeatherNames={[20]='ROUTE119_CYCLE',[21]='ROUTE123_CYCLE'}}}
  local context={save=save,game={data=data},overworld={}}
  Commands.g3_weather(context,20)
  T.eq(save.gen3Weather,5,'script stores the translated cycle byte')
  T.eq(context.overworld.gen3Weather,5,'script context sees the same committed byte')
  T.eq(save.gen3WeatherActive,2,'script setter does not run doweather early')
  T.eq(S.get(save,40),1,'scripted cycle counts its one original rain transition')
  Commands.g3_do_weather(context)
  T.eq(save.gen3WeatherActive,5,'doweather activates the saved answer')
  T.eq(S.get(save,40),1,'doweather never counts rain twice')
  Gen3Commands.setCycleWeather(context,'ROUTE119_CYCLE')
  T.eq(S.get(save,40),1,'cycle special delegates to the same saved-weather setter')
  Game.data,Game.save=data,save
  local world={map={id='A',def={weather=21}},
    updateGen3WeatherStage=function()return save.gen3WeatherStage end}
  OW.applyMapWeather(world,{via='warp'})
  T.eq(save.gen3Weather,3,'map header stores its translated original cycle')
  T.eq(save.gen3WeatherActive,3,'map entry activates its committed answer immediately')
  T.eq(S.get(save,40),2,'map entry counts one changed rainy header')
  OW.applyMapWeather(world,{via='warp'})
  T.eq(S.get(save,40),2,'adjacent same-weather map entry does not increment')
  save.gen3Weather,save.gen3WeatherStage=20,2
  W.set(save,20)
  T.eq(S.get(save,40),2,'legacy unresolved saves are normalized without invented rain visits')
  save.gen3Weather=2;save.gen3Stats[40]=S.MAX
  W.set(save,3)
  T.eq(S.get(save,40),S.MAX,'native game-stat saturation is retained')
  T.eq(W.resolve(nil,save,15),edition=='emerald'and 15 or 0,'only Emerald owns abnormal mode15')
  T.eq(W.resolve(nil,save,255),0,'unsupported original weather translates to none')
end
V.set('emerald')
local save={gen3Weather=2,gen3WeatherActive=2,gen3Stats={[40]=0},inventory={POTION=3}}
local oldRandom,oldTime,oldLoveRandom=math.random,os.time,love.math.random
math.random=function()error('saved weather consumed gameplay RNG')end
love.math.random=math.random;os.time=function()error('saved weather polled the calendar')end
W.set(save,3)
math.random,os.time,love.math.random=oldRandom,oldTime,oldLoveRandom
T.eq(S.get(save,40),1,'commit uses the recorded cycle stage without clocks or randomness')
T.eq(save.inventory.POTION,3,'rain statistics preserve inventory')
V.set('gold')
save={gen3Weather=2,gen3Stats={[40]=7}}
W.set(save,3)
T.eq(S.get(save,40),7,'non-GBA callers cannot gain a Gen3 weather statistic')
V.set(oldVersion);Game.save,Game.data=oldSave,oldData
T.finish('All-five GBA saved weather translation, original rain counter and deferred activation')
