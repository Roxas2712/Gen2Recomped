package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local clock=0;love.timer={getTime=function()return clock end}
local account='17'
package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return account end}
local response,problem,status,requests={},nil,nil,{}
package.loaded['src.cloud.Tournaments']={request=function(_,_,_,payload)requests[#requests+1]=payload;return response,problem,status end}
package.loaded['src.cloud.Task']={new=function(fn)return{poll=function()local a,b=fn();return{kind='done',first=a,second=b}end,cancel=function()end}end}
local N=require('src.link.CloudNet');local n=N.new('cup','match','battle','ticket')
n:send({type='hello',name='ME'});local body=n.outbox[1].body
n:update();response=nil;problem='temporary outage';n:update()
assert(#n.outbox==1 and not n.closed,'temporary errors preserve the queued action')
clock=2;n:update();response={battle='battle',sent=1,messages={{sequence=1,body='{"type":"hello","name":"PEER"}'}}};n:update()
assert(#n.outbox==0 and n:poll()[1].name=='PEER' and n.received==1,'messages are acknowledged and delivered in order')
assert(requests[1].messages[1].body==body and requests[2].messages[1].body==body,'retry uses the same sequence and payload bytes')
n:send({type='bye'});n:close();clock=3;N.pump();response={battle='battle',sent=2,messages={}};N.pump()
assert(n.finished and requests[#requests].close and requests[#requests].after==1,'closing flushes queued protocol data and its receive acknowledgement')
local bad=N.new('cup','match','battle','ticket');clock=4;bad:update();response={battle='battle',sent=0,messages={{sequence=2,body='{"type":"action"}'}}};bad:update()
assert(bad.closed and bad.error,'a gap cannot silently deliver a different turn')
local switched=N.new('cup','match','battle','ticket');account='18';switched:update()
assert(switched.closed and switched.error,'switching accounts closes the old battle transport')
account='17';local gone=N.new('cup','match','battle','ticket');gone.hasPeer=true;clock=5;gone:update();response={battle='battle',sent=0,peer_online=false,messages={}};gone:update()
assert(gone.closed and gone.error,'a vanished rival ends the connection instead of waiting forever')
local departing=N.new('cup','match','battle','ticket');clock=6;departing:update()
response={battle='battle',sent=0,peer_closed=true,messages={{sequence=1,body='{"type":"bye"}'}}};departing:update()
assert(departing.closed and departing:poll()[1].type=='bye','a graceful peer exit delivers the final message and closes the battle')
clock=7;N.pump();response={battle='battle',sent=0,peer_closed=true,messages={}};N.pump()
assert(departing.finished and requests[#requests].after==1 and requests[#requests].close,'the last peer message is acknowledged before retirement')
local tail=N.new('cup','match','battle','ticket');clock=8;tail:update()
local batch={};for i=1,8 do batch[i]={sequence=i,body='{"type":"hash"}'} end
response={battle='battle',sent=0,peer_closed=true,messages=batch};tail:update()
assert(not tail.closed and #tail:poll()==8,'a full final page does not close before the remaining messages are fetched')
clock=9;tail:update();response={battle='battle',sent=0,peer_closed=true,messages={{sequence=9,body='{"type":"bye"}'}}};tail:update()
assert(tail.closed and tail.received==9 and tail:poll()[1].type=='bye','a closed peer stream is drained across multiple pages')
local cancelled=N.new('cup','match','battle','ticket');clock=10;cancelled:update()
response=nil;problem='This battle connection is no longer active.';status=422;cancelled:update()
assert(cancelled.closed and cancelled.error==problem,'a cancelled pairing ends immediately instead of waiting through transient retries')
local limited=N.new('cup','match','battle','ticket');clock=11;limited:send({type='action'});limited:update();status=429;limited:update()
assert(not limited.closed and #limited.outbox==1,'rate limiting preserves the pending action for retry')
clock=12;limited:update();status=nil;problem=nil;response={battle='battle',sent=1,messages={}};limited:update()
assert(not limited.closed and #limited.outbox==0,'the same action recovers after a temporary rate limit')
print('Cloud Arena transport: 14 checks passed')
