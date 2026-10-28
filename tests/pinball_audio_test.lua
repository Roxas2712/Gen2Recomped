-- Exercise the real Player consumer against a bounded queue and starvation.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');local noop=function()end
love.filesystem.read=function()end;love.filesystem.write=function()return true end
love.keyboard.isDown=function()return false end;love.mouse.isDown=function()return false end
love.joystick={getJoysticks=function()return{}end};love.window.hasFocus=function()return true end
local function channel()return{items={},clear=function(self)self.items={}end,pop=function(self)return table.remove(self.items,1)end,push=function(self,v)self.items[#self.items+1]=v end,getCount=function(self)return #self.items end}end
love.thread={getChannel=channel,newThread=function()return{start=noop,isRunning=function()return false end,getError=noop}end}
local sources={}
love.audio={newQueueableSource=function(_,_,_,capacity)
 local s={capacity=capacity,queued=0,playing=false,starts=0,setVolume=noop,release=noop}
 function s:stop()self.playing=false;self.queued=0 end
 function s:isPlaying()return self.playing end
 function s:getFreeBufferCount()return self.capacity-self.queued end
 function s:queue()assert(self.queued<self.capacity);self.queued=self.queued+1;return true end
 function s:play()self.playing=true;self.starts=self.starts+1 end
 sources[#sources+1]=s;return s
end}
local cap=require('src.core.FrameCap');local player=require('src.pinball.Player').new({},{});player.ready=true
local function add(count,rate)
 for _=1,count do player.audio:push({getSampleRate=function()return rate or 32768 end,release=noop})end
 player:update(.016)
end
add(5);assert(not player.sound.playing,'short startup must prebuffer instead of immediately underrunning')
add(1);assert(player.sound.playing and player.sound.starts==1)
player.sound.playing=false;player.sound.queued=0
add(5);assert(not player.sound.playing,'starved playback must refill before restarting')
add(1);assert(player.sound.playing and player.audioRestarts==1)
add(6,65536);assert(player.audioRate==65536 and player.sound.playing and #sources==2,'rate changes must retain a correctly sized new queue')
assert(cap.realtime());player:togglePause();assert(not cap.realtime() and not player.sound.playing)
add(6,65536);assert(player.audio:getCount()==0 and player.sound.queued==0,'paused menus must discard live duel audio instead of replaying it late')
player:togglePause();assert(cap.realtime())
local function phase(value)
 player.videoStarted=true
 player.frames:push({images={},stats={},seconds=0,phase=value,frame=1})
 player:update(.016)
end
phase('waiting');assert(not player.sound.playing and not player.audioStarted,'joint-start waiting ends preparation audio deliberately')
phase('playing');add(6,65536)
assert(player.sound.playing and player.audioRestarts==1,'resuming after intentional native waiting is not audio starvation')
phase('finished');assert(not player.sound.playing,'completed native game must not replay queued sound while awaiting the peer')
player:dispose();assert(not cap.realtime())
print('Pinball audio: startup preroll, starvation recovery, sample-rate change, pause and lease cleanup passed')
