package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local files={}
local disk={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
 createDirectory=function() return true end,remove=function(p) files[p]=nil;return true end,
 getInfo=function(p) return files[p] and {size=#files[p]} end,
 getDirectoryItems=function(dir) local out={};for path in pairs(files) do local name=path:match('^'..dir..'/([^/]+)$');if name then out[#out+1]=name end end;return out end}
love.data={hash=function(_,bytes) local h=5381;for i=1,#bytes do h=(h*33+bytes:byte(i))%4294967296 end;return string.rep(string.format('%08x',h),8) end,encode=function(_,_,v) return v end}
package.loaded['src.core.SaveData']={persistenceFs=function() return disk end}
local signed=true
package.loaded['src.cloud.RetroCloud']={API='https://example.invalid/api/cloud/v1',signedIn=function() return signed end,
 account=function() return 'test@example.invalid' end,accessToken=function() return signed and string.rep('a',64) or nil,'Registration required.' end}
local Json=require('src.link.Json');local S=require('src.core.SaveSerializer');local B=require('src.storage.PokemonBank')
local http={};local response={};local offline=false
package.loaded['src.cloud.Http']={request=function(method,url,opts)
 http[#http+1]={method=method,url=url,opts=opts,body=opts.body and Json.decode(opts.body)}
 if offline then return nil,'offline' end
 return 200,Json.encode(response)
end}
local T=require('src.cloud.BankExchange')
local first=assert(T.device());package.loaded['src.cloud.BankExchange']=nil;T=require('src.cloud.BankExchange')
check(T.device()==first and #first==32,'the same installation keeps its device identity across reloads and session changes')
local entry={schema=1,source={version='red',slot='slot1',place='Party 1'},mon={species='BULBASAUR',level=5,moves={{id='TACKLE'}}},canonical={dex=1,moves={{name='TACKLE'}}}}
signed=false;check(not T.submit(entry,'wonder') and not T.submit(entry,'direct','RRC-ABCDEF-012345') and not T.profile() and #http==0,'both direct trade and Wonder Trade require registration before networking')
signed=true;offline=true
check(not T.submit(entry,'wonder'),'an unavailable network leaves a retryable offer')
local nonce=http[#http].body.nonce;local deviceHeader=http[#http].opts.headers['X-Retro-Device']
check(deviceHeader==first and http[#http].opts.sensitive,'requests send the persistent device ID through the private authenticated transport')
offline=false;local exchange='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
response={id=exchange,status='pending'}
check(T.submit(entry,'wonder') and http[#http].body.nonce==nonce,'retrying after a timeout reuses the durable request nonce')
response={id=exchange,status='cancelled'};assert(T.change(exchange,'cancel'))
response={id=exchange,status='pending'};assert(T.submit(entry,'wonder'))
check(http[#http].body.nonce~=nonce,'a cancelled request can be replaced by a deliberate new offer')
local bytes=S.encode(entry);local hash=love.data.hash('sha256',bytes)
response={status='completed',incoming_entry=bytes,incoming_digest=hash,partner='RRC-ABCDEF-012345',mode='wonder'}
local received=assert(T.receive(exchange))
check(received.id==hash and #B.list()==1 and not received.alreadyReceived,'a completed exchange verifies and durably imports its Bank copy')
check(T.receive(exchange).alreadyReceived and #B.list()==1,'collecting the same receipt on retry cannot duplicate its immutable Bank entry')
response.incoming_digest=string.rep('0',64)
check(not T.receive(exchange) and #B.list()==1,'a fingerprint mismatch never alters the existing Bank')
local before=#http;files[T.JOURNAL]='broken journal'
check(not T.submit(entry,'wonder') and #http==before and files[T.JOURNAL]=='broken journal','an unreadable request journal is preserved instead of silently generating a duplicate offer')
local Policy=require('src.storage.AccountStorage');local oldCheck=Policy.check
Policy.check=function() return nil,'The active account changed.' end
before=#http
check(not T.profile() and #http==before,'account-bound jobs refuse networking before reading a new account token')
Policy.check=oldCheck
print('Bank exchange: '..n..' checks passed')
