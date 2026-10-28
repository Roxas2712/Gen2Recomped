-- Real native owners, synthetic device handles; no ROM or sound device.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Contract=require('tools.audio-shutdown-contract-check.cases')
local A=require('src.core.game3.audio');local S=require('src.core.Sound')
local Music=require('src.core.Music');local Stream=require('src.core.game3.asset_stream')
local G=require('src.core.Game3');local Host=require('src.mods.Runtime');local Cry=require('src.core.NativeCryPlayer')
local previous=love.audio
local created={}
local function source(path,kind)
 local s={playing=false,volume=1,path=path,kind=kind,stops=0}
 function s:play()self.playing=true end
 function s:stop()self.playing=false;self.stops=self.stops+1 end
 function s:isPlaying()return self.playing end
 function s:pause()self.playing=false end
 function s:setVolume(n)self.volume=n end
 function s:getVolume()return self.volume end
 function s:setLooping(n)self.looping=n end
 function s:isLooping()return self.looping==true end
 function s:setPitch(n)self.pitch=n end
 function s:setPosition()end
 function s:setRelative()end
 function s:getChannelCount()return 2 end
 function s:getType()return self.kind or'static'end
 function s:setFilter()end
 function s:seek()end
 function s:tell()return 0 end
 function s:getDuration()return 1 end
 function s:clone()return source(self.path,self.kind)end
 created[#created+1]=s;return s
end
love.audio={newSource=source}
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f
 Contract.run(A,T,function()
  Stream.shutdown();S.invalidate();Music.stop();G.release()
  f=require('tools.session-runtime.fixture').new(edition);local g=f.game
  g.data.audio={sfx={SE_OWNED='synthetic.wav'},cries={FIXMON_A={file='cry.wav'}},
   songs={BOOT={file='boot.wav'},SONG_001={index=1,sfxName='SE_OWNED',file='synthetic.wav',player=1}}}
  Host.currentMod='first_owner';g.save.options.sfxVol=7;S.setVolumeLevel(7)
  Music.play(g.data,'BOOT',true);local music=created[#created]
  T.eq(Music.current(),'BOOT',edition..' actual native menu music starts')
  T.eq(A.playSe(1),true);local se=A._seSources[1];T.eq(se:isPlaying(),true)
  local cry=assert(S.playCry(g.data,'FIXMON_A'))
  local outside=source('outside.wav');outside:play()
  local clock=Cry.snapshot().clock
  local environment={music=music,se=se,cry=cry,outside=outside,currentSong=Music.current}
  environment.restartCry=function()environment.cry=assert(S.playCry(g.data,'FIXMON_A'))end
  environment.afterStop=function()
   T.eq(#A._seSources,0,'borrowed voice observations retire in place')
   T.eq(Cry.snapshot().clock,clock,'source shutdown never ticks the native cry clock')
   A.update(1/60);A.update(1/60)
   T.eq(Cry.snapshot().clock,clock,'source polling retains the native clock owner')
   T.eq(A.playSe(1),true,'playback remains available after shutdown')
   T.eq(A._seSources[1],se,'compiled sound cache remains reusable')
   A.stopAll()
  end
  environment.cleanup=function()
   Host.currentMod='first_owner';T.eq(A.playSe(1),true)
   Host.currentMod='peer';T.eq(A.playSe(1),true)
   local peer=A._seSources[#A._seSources]
   Host.currentMod='first_owner';A.stopAll();T.eq(peer:isPlaying(),false,'explicit whole-session stop includes another source owner')
   -- Exercise the same portable callback shape as a native boot wrapper.
   local base=G._handleBootAction;local calls=0
   G._handleBootAction=function(view,action)A.stopAll();return base(view,action)end
   local ok,why,hole,last=pcall(G._bootAction,g,{action='new_game'},function()calls=calls+1;return 'boot',nil,9 end)
   G._handleBootAction=base
   T.eq(ok,true,tostring(why));T.eq(why,'boot');T.eq(hole,nil);T.eq(last,9)
   T.eq(calls,1,'native boot body executes once after source shutdown')
   S.invalidate();Music.stop();Stream.shutdown();G.release();Host.currentMod=nil
  end
  return environment
 end)
end
love.audio=previous
T.finish('portable audio shutdown, native boot delegation and native playback/cache ownership')
