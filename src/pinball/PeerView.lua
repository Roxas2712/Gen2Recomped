-- Optional live pictures over existing authenticated WebRTC / WSS transport.
-- Rules, scores, cancellation and final ACKs remain on CloudNet. By Roxas2712.
local M={};M.__index=M
local Peer=require('src.link.PeerNet')
local function integer(n,max)return type(n)=='number'and n%1==0 and n>=1 and n<=max end
function M.packet(p)
 return type(p)=='table'and p.type=='pinball_picture'and p.protocol==1
  and integer(p.frame,25000)and integer(p.width,512)and integer(p.height,512)
  and type(p.png)=='string'and #p.png>=44 and #p.png<=27000
end
function M.available(net)return net and type(net.peerTicket)=='function'and Peer.available()end
function M.new(net,options)
 local transport=Peer.new(net.peerTicket,nil,{ephemeral=true,forceRelay=options and options.forceRelay})
 if not transport then return end
 return setmetatable({net=transport,path='connecting',sent=0,received=0,dropped=0,directFrames=0,relayFrames=0},M)
end
function M:stop()if self.net then self.net:close()end end
function M:update()
 if self.error then return end
 self.net:update();self.path=self.net.path
 if self.net.closed or self.net.error then self.error=self.net.error or 'Live connection ended';self:stop();return end
 local latest
 for _,packet in ipairs(self.net:poll())do
  if not M.packet(packet)then self.error='Invalid live picture envelope';self:stop();return end
  self.received=self.received+1
  if not latest or packet.frame>latest.frame then latest=packet end
 end
 return latest
end
function M:send(packet)
 if self.error or not self.net.paired or self.net.closed or (self.path~='p2p'and self.path~='relay')then return false end
 if #self.net.outbox>=3 then self.dropped=self.dropped+1;return true end
 local message={type='pinball_picture',protocol=1,frame=packet.frame,width=packet.width,height=packet.height,png=packet.png}
 if not M.packet(message)then return false end
 self.net:send(message);if self.net.error then return false end
 self.sent=self.sent+1
 if self.path=='p2p'then self.directFrames=self.directFrames+1 else self.relayFrames=self.relayFrames+1 end
 return true
end
return M
