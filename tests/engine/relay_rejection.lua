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
