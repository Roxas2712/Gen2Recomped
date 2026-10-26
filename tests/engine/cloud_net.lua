package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local clock=0;love.timer={getTime=function()return clock end}
local account='17'
package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return account end}
local response,problem,requests={},nil,{}
package.loaded['src.cloud.Tournaments']={request=function(_,_,_,payload)requests[#requests+1]=payload;return response,problem end}
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
print('Cloud Arena transport: 7 checks passed')
