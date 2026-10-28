-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');local time=0;love.timer={getTime=function()return time end}
local account='1';package.loaded['src.cloud.RetroCloud']={signedIn=function()return account~=nil end,accountId=function()return account end}
package.loaded['src.cloud.Task']={new=function(fn)return{poll=function()local a,b=fn();return{kind='done',first=a,second=b}end,cancel=function()end}end}
local natives={}
package.loaded['src.link.NativePeer']={available=function()return true end,open=function(doc)
 local n={events={},sent={},doc=doc};natives[#natives+1]=n
 function n:poll()return table.remove(self.events,1)end
 function n:start()self.started=true;return true end
 function n:restart()self.restarted=true;return true end
 function n:send(body,direct)self.sent[#self.sent+1]={body=body,direct=direct};return true end
 function n:close()self.closed=true end
 return n
end}
local N=require('src.link.PeerNet');local Json=require('src.link.Json');local count=0
local function check(v,m)assert(v,m);count=count+1 end
local function journal(seq,received)
 local j={sequence=seq or 0,received=received or 0,accepted=seq or 0,outbox={},inbox={}}
 function j:send(m)self.sequence=self.sequence+1;self.outbox[#self.outbox+1]=m end
 function j:update()end
 function j:poll()local a=self.inbox;self.inbox={};return a end
 function j:close()self.closed=true end
 return j
end
local function ticket()return{transport={schema=1,url='wss://relay.example/v1/rooms/play:00000000-0000-0000-0000-000000000000',ticket='fixture',role='left',expires_in=75}}end
local function ready(j)
 local net=N.new(ticket,j);net:update();net:update();local native=net.native
 native.events={{kind=1},{kind=2,a=Json.encode({t='ready',peer='first'})}};net:update();return net,native
end
local j=journal();local net,native=ready(j)
check(net.paired and net.path=='relay'and native.started,'authorized relay works while ICE is negotiating')
native.events={{kind=6}};net:update();check(net.path=='p2p','native channel upgrades the live route')
net:send({type='action',slot=1});net:update();check(Json.decode(native.sent[#native.sent].body).sequence==1 and native.sent[#native.sent].direct,'action travels directly with its stable sequence')
net:frame({t='ack',after=1});check(#net.outbox==0 and not net:checkpoint(),'live acknowledgement cannot invent a durable server checkpoint')
j.accepted=1;net:update();check(net:checkpoint(),'server journal acknowledgement releases the checkpoint')
local one=Json.encode({type='party',index=1});local two=Json.encode({type='action',index=2})
net:frame({t='packet',sequence=2,body=two});check(#net:poll()==0,'out-of-order data waits for the missing prefix')
net:frame({t='packet',sequence=1,body=one});local rows=net:poll();check(#rows==2 and rows[1].index==1 and rows[2].index==2,'messages are applied exactly once in order')
net:frame({t='packet',sequence=2,body=two});check(#net:poll()==0,'identical replay is idempotent')
net:frame({t='packet',sequence=2,body=one});check(net.closed and net.error:find('changed',1,true),'a changed duplicate fails closed')
local nj=journal();local n,nn=ready(nj);nn.events={{kind=6}};n:update();n:send({type='confirm',ok=true});nn.events={{kind=8}};n:update()
check(n.path=='relay'and #n.outbox==1,'direct disconnection keeps the pending transaction for relay retry')
check(not nn.sent[#nn.sent].direct,'fallback transmits over the existing secure relay')
nn.events={{kind=2,a=Json.encode({t='ready',peer='replacement'})}};n:update();check(nn.restarted,'device replacement renegotiates the native channel')
n:frame({t='ack',after=1});nj.accepted=1;n:update();n:close();check(n.closing and not nn.closed,'closing waits for the final acknowledged messages')
N.pump();check(nn.closed and nj.closed,'completed close releases both relay and journal')
local restored,rn=ready(journal(10,20));check(restored.sequence==10 and restored.received==20,'device resume preserves both persisted cursors')
restored:frame({t='packet',sequence=21,body=one});check(#restored:poll()==1,'resumed stream continues at the next exact message')
local old=journal();local fallback=N.new(function()return nil,'disabled',503 end,old);fallback:update();fallback:update();check(fallback.path=='https'and not old.journalOnly,'older or disabled services retain the existing transport')
local revoked=N.new(function()return nil,'This battle was transferred to another device.',409 end,journal());revoked:update();revoked:update();check(revoked.closed and revoked.transferred,'old device lease is terminal')
local signed,an=ready(journal());account=nil;signed:update();check(signed.closed and an.closed,'account changes close direct and relay routes')
print('Peer transport: '..count..' checks passed')
