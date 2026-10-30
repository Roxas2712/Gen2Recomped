package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.system={getOS=function()return 'Windows'end}
love.filesystem.getSaveDirectory=function()return 'C:/Users/Ömega % !/App Data'end
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local calls=0;local code,body=200,'{}';local last
package.loaded.https={request=function(url,opts)calls=calls+1;last=opts;return code,body end}
require('src.core.HostShell').popen=function()error('Windows native HTTPS must not spawn cmd.exe')end
local H=require('src.cloud.Http')
check(H.available(),'Windows native transport is available without curl')
local payload=[[Ünicode save bytes % ! \ paths]]
local c=H.request('PUT','https://example.invalid/save',{sensitive=true,body=payload,headers={Authorization='Bearer fixture'}})
check(c==200 and last.data==payload and last.headers.Authorization=='Bearer fixture','native transport preserves body and authentication without shell encoding')
check(not H.request('PUT','http://example.invalid/save',{sensitive=true,body=payload}) and calls==1,'native transport refuses plaintext credentials')
check(not H.request('PUT','https://example.invalid/save',{sensitive=true,headers={Authorization='bad\nheader'}}) and calls==1,'native transport rejects injected headers')
local R=require('src.cloud.RetroCloud');R.accessToken=function()return string.rep('a',64)end;R.accountId=function()return '17'end;R.account=function()return 'fixture@example.invalid'end
body='{"objects":[]}'
local store=assert(R.open());code=413;body='{}'
local ok,why=store.write('saves/red/fixture.lua','fixture')
check(not ok and why:find('size limit',1,true),'size-limit rejection has an actionable explanation')
code=507;ok,why=store.write('saves/red/fixture.lua','fixture')
check(not ok and why:find('storage is full',1,true),'full account quota is reported explicitly')
code=429;ok,why=store.write('saves/red/fixture.lua','fixture')
check(not ok and why:find('Wait a moment',1,true),'rate limits explain how to retry')
print('Windows cloud HTTP contracts: '..checks..' checks passed (simulated Windows, native API fixture)')
