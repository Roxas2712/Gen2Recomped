-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');local clock=0;local port=30000;love.math=love.math or{};love.math.random=function()port=port+1;return port end
local n=0;local function check(v,m)assert(v,m);n=n+1 end
package.loaded['src.link.Handshake']={hello=function()return{fingerprint='same-fixture'}end}
package.loaded['src.core.GameVersion']={get=function()return'crystal'end}
local sockets,hosts,sent={},{},{}
local socket={udp=function()
 local u={q={}};sockets[#sockets+1]=u
 function u:settimeout()end;function u:setoption()return true end;function u:setsockname()return true end
 function u:sendto(bytes)for _,other in ipairs(sockets)do if other~=self and not other.closed then other.q[#other.q+1]=bytes end end end
 function u:receivefrom()return table.remove(self.q,1),'192.0.2.10'end
 function u:close()self.closed=true end
 return u
end}
local function makeNet()
 local net={inbox={}}
 function net:host(p)port=port+1;self.port=p==0 and port or p;hosts[self.port]=self;return true end
 function net:join(address)local p=tonumber(address:match(':(%d+)$'));local h=hosts[p];if not h or h.closed then return false end;self.peer=h;h.peer=self;self.paired=true;h.paired=true;return true end
 function net:send(m)sent[#sent+1]=m.type;if self.peer then self.peer.inbox[#self.peer.inbox+1]=m end end
 function net:update()end
 function net:poll()local q=self.inbox;self.inbox={};return q end
 function net:close()self.closed=true end
 return net
end
local N=require('src.link.Nearby');local game={save={player={name='Local Trainer'}}}
local function new(id)return assert(N.new(game,'trade',{socket=socket,makeNet=makeNet,clock=function()return clock end,id=id}))end
local a,b=new('left'),new('right');a:update();b:update();a:update()
check(a.peers.right and b.peers.left,'ready local devices discover each other without account credentials')
check(a:request('right'),'selecting a discovered player sends an explicit request')
a:update();b:update();check(b.phase=='incoming'and a.phase=='requesting','the other device has an accept/decline choice')
check(#sent==1 and sent[1]=='near_request','no handshake or party is sent before mutual consent')
b:respond(true);a:update();check(a.phase=='accepted'and b.phase=='accepted','acceptance completes on both devices')
local left,lh=a:take();local right,rh=b:take();check(left and right and not lh and rh,'the accepted reliable transport transfers to host/guest link roles')
local c,d=new('c'),new('d');c:update();d:update();c:update();c:request('d');c:update();d:update();d:respond(false);c:update()
check(c.phase=='listening'and d.phase=='listening','declining returns both devices to discovery without starting a trade')
clock=6;c:update();check(not c.peers.d,'stale local advertisements expire')
c:close();d:close();left:close();right:close();check(c.closed and d.closed,'closing the lobby closes discovery sockets')
print('Nearby lobby: '..n..' checks passed')
