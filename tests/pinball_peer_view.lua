-- Picture routing stays independent of authoritative duel control. By Roxas2712.
package.path='./?.lua;'..package.path
local transport={paired=false,path='connecting',outbox={},inbox={}}
function transport:update()end
function transport:send(m)self.sent=m end
function transport:poll()local a=self.inbox;self.inbox={};return a end
function transport:close()self.closed=true end
package.loaded['src.link.PeerNet']={available=function()return true end,new=function(_,journal,options)assert(journal==nil and options.ephemeral);return transport end}
local M=require('src.pinball.PeerView');assert(M.available({peerTicket=function()end}))
local view=M.new({peerTicket=function()end});local picture={frame=1,width=240,height=348,png=string.rep('a',44)}
assert(not view:send(picture),'connecting retains HTTPS fallback')
transport.paired=true;transport.path='p2p';view:update()
assert(view:send(picture)and transport.sent.type=='pinball_picture'and view.directFrames==1)
transport.path='relay';view:update();assert(view:send(picture)and view.relayFrames==1)
transport.outbox={1,2,3};assert(view:send(picture)and view.dropped==1,'backpressure drops old previews instead of filling SQL fallback')
transport.inbox={{type='pinball_picture',protocol=1,frame=9,width=240,height=348,png=picture.png},{type='pinball_picture',protocol=1,frame=8,width=240,height=348,png=picture.png}}
assert(view:update().frame==9 and view.received==2,'latest picture wins across transports')
transport.inbox={{type='pinball_duel',protocol=1,kind='score'}};assert(view:update()==nil and view.error and transport.closed,'peer pictures cannot inject duel scores')
assert(not view:send(picture),'failed peer channel returns control to HTTPS pictures')
print('Pinball peer view: routing, bounded queue, latest frame and control isolation passed')
