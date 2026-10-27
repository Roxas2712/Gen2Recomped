-- A public relay rejection must reach the UI without waiting for a room.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local Net=require('src.link.Net')
local Json=require('src.link.Json')
local n=Net.new()
local line=Json.encode({type='upgrade_required',protocol=3,minBuild='0.3.96'})..'\n'
n.rxBuf=line:sub(1,9);n:drainLines()
assert(not n.closed,'a partial network frame is not a rejection')
n.rxBuf=n.rxBuf..line:sub(10);n:drainLines()
assert(n.closed and n.error=='This relay needs a newer online protocol.',
       'an incompatible relay must fail with a clear protocol error')
assert(#n:poll()==0,'a server rejection must never reach the peer protocol')
local peer=Net.new()
peer:handleTCPLine(Json.encode({type='hello',name='PEER'}))
assert(not peer.closed and peer:poll()[1].name=='PEER','normal peer traffic stays available')
print('Relay rejection: 4 checks passed')

-- Legacy room codes and tournament relay entry points also require a confirmed
-- live ModCompass session. No account credential is sent to the public relay.
local sockets, requests, signed, identity = 0, 0, false, '7'
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return identity end}
local response, problem
package.loaded['src.cloud.NativeAccount']={request=function(method,path,payload,authorized)
  requests=requests+1
  assert(method=='GET' and path=='/community/counts' and payload==nil and authorized)
  return response,problem
end}
package.loaded.socket={tcp=function()
  sockets=sockets+1
  return {settimeout=function()end,connect=function()return true end,close=function()end}
end}
package.loaded['src.link.Net']=nil
Net=require('src.link.Net')
assert(not Net.new():hostOnline() and not Net.new():joinOnline(nil,'ABC123'))
assert(sockets==0 and requests==0,'guest online entry never opens a relay socket')
signed=true;problem='Please connect this device again.'
assert(not Net.new():connectTCP('example.invalid:7778') and sockets==0,'revoked sessions cannot connect')
problem=nil;response={account_id='8'}
assert(not Net.new():hostOnline() and sockets==0,'a different account response is refused')
response={account_id='7'}
local member=Net.new();assert(member:hostOnline() and sockets==1)
assert(not member.txBuf:find('Bearer') and member.txBuf:find('host'),'the relay sees room control only')
assert(Net.loopbackPair().paired,'offline loopback remains available')
print('Online member gate: 8 checks passed')
