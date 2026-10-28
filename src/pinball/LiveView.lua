-- Bounded live opponent pictures. No second game is simulated. By Roxas2712.
local M={};M.__index=M
local Json=require('src.link.Json')
function M.new(channel)
 local self=setmetatable({channel=channel,frame=0,received=0},M)
 for _,kind in ipairs{'previewReceive','previewFrames','previewEncoded','previewEvents','previewQuit'}do
  self[kind]=love.thread.getChannel(channel..'.'..kind);self[kind]:clear()
 end
 self.thread=love.thread.newThread('src/pinball/live_view_worker.lua');self.thread:start(channel)
 return self
end
function M:receive(picture)
 self.previewReceive:performAtomic(function(channel)channel:clear();channel:push(Json.encode(picture))end)
end
function M:update()
 local event=self.previewEvents:pop();if event then self.error=event end
 local why=self.thread:getError();if why then self.error=why end
 local picture=self.previewFrames:pop()
 if picture then self.frame=picture.frame;self.received=self.received+1 end
 local packet=self.previewEncoded:pop()
 return picture and picture.image,packet and Json.decode(packet)
end
function M:stop()self.previewQuit:push(true)end
function M:dispose()
 self:stop();self.thread:wait()
 for _,name in ipairs{'previewSource','previewFrames'}do
  local channel=love.thread.getChannel(self.channel..'.'..name)
  local value=channel:pop();while value do value.image:release();value=channel:pop()end
 end
end
return M
