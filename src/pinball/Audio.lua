-- One native worker owns the source; UI/network stalls cannot stop its pump.
-- Original PCM and cartridge clock remain unchanged. By Roxas2712.
local M={};M.__index=M
local CAPACITY,PREROLL=32,6
function M.new(volume,diagnostics)
 return setmetatable({volume=volume or .6,diagnostics=diagnostics,active=true,restarts=0,dropped=0,history={}},M)
end
function M:setActive(value)
 if self.active==value then return end
 self.active=value;self.started=false
 if self.source then self.source:stop();self.source:release();self.source=nil;self.rate=nil end
end
function M:setVolume(value)
 if type(value)~='number'or value~=value then return end
 self.volume=math.max(0,math.min(1,value))
 if self.source then self.source:setVolume(self.volume)end
end
function M:push(data,context)
 if not self.active then data:release();return end
 local rate=data:getSampleRate()
 if rate~=self.rate then
  if self.source then self.source:stop();self.source:release()end
  self.rate=rate;self.source=love.audio.newQueueableSource(rate,16,1,CAPACITY)
  self.source:setVolume(self.volume);self.started=false
 end
 if self.source:getFreeBufferCount()>0 then
  local ok,accepted=pcall(self.source.queue,self.source,data)
  data:release()
  assert(ok and accepted~=false,'Native audio output refused a PCM block')
 else self.dropped=self.dropped+1;data:release()end
 if not self.source:isPlaying()and CAPACITY-self.source:getFreeBufferCount()>=PREROLL then
  if self.started then
   self.restarts=self.restarts+1
   if self.diagnostics and #self.history<16 then
    context=context or{};context.at=love.timer.getTime();self.history[#self.history+1]=context
   end
  end
  self.source:play();self.started=true
 end
end
function M:close()
 self:setActive(false)
 if self.source then self.source:release();self.source=nil end
end
return M
