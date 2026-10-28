-- Exercise the worker-owned audio output against queue bounds and starvation.
package.path='./?.lua;'..package.path
local noop=function()end;love={timer={getTime=function()return 1 end}};local sources={};local released=0
love.audio={newQueueableSource=function(_,_,_,capacity)
 local s={capacity=capacity,queued=0,playing=false,starts=0,setVolume=noop,releases=0}
 function s:release()self.releases=self.releases+1 end
 function s:stop()self.playing=false;self.queued=0 end
 function s:isPlaying()return self.playing end
 function s:getFreeBufferCount()return self.capacity-self.queued end
 function s:queue()assert(self.queued<self.capacity);self.queued=self.queued+1;return true end
 function s:play()self.playing=true;self.starts=self.starts+1 end
 sources[#sources+1]=s;return s
end}
local out=require('src.pinball.Audio').new(.6,true)
local function add(count,rate)
 for _=1,count do out:push({getSampleRate=function()return rate or 32768 end,release=function()released=released+1 end},{frame=1,phase='playing'})end
end
add(5);assert(not out.source.playing,'short startup must prebuffer')
add(1);assert(out.source.playing and out.source.starts==1)
out.source.playing=false;out.source.queued=0
add(5);assert(not out.source.playing,'starved playback must refill')
add(1);assert(out.source.playing and out.restarts==1 and #out.history==1)
add(6,65536);assert(out.rate==65536 and out.source.playing and #sources==2 and sources[1].releases==1)
out:setActive(false);add(6,65536);assert(not out.source and not out.started and sources[2].releases==1,'waiting or host pause discards even unplayed PCM buffers')
out:setActive(true);add(6,65536);assert(out.source.playing and out.restarts==1,'intentional pause is not counted as starvation')
add(40,65536);assert(out.source.queued==32 and out.dropped==14,'catch-up remains bounded even if hardware cannot accept more')
out:close();out:close();assert(not out.source and sources[3].releases==1)
assert(released==70,'every PCM block releases its worker proxy exactly once')
print('Pinball worker audio: preroll, underrun, rates, pause, bounds and release passed')
