package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local files={};local fs={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
 getInfo=function(p) return files[p] and {size=#files[p]} end,remove=function(p) files[p]=nil;return true end}
love.filesystem=fs
local Json=require('src.link.Json');local S=require('src.core.SaveSerializer')
local status,body=200,Json.encode({objects={}})
package.loaded['src.cloud.Http']={request=function() return status,body end,json=function(code,bytes) return code,Json.decode(bytes) end}
local function fresh() package.loaded['src.cloud.RetroCloud']=nil;return require('src.cloud.RetroCloud') end
local R=fresh();local n=0;local function check(v,m) assert(v,m);n=n+1 end
local token=string.rep('a',64)
assert(R.acceptConnection({access_token=token,expires_in=2592000,email='fixture@example.test',account_id='17',name='Fixture'}))
local record=S.decode(files[R.FILE]);record.expires=1;files[R.FILE]=S.encode(record)
R=fresh()
check(R.signedIn() and R.accessToken()==token and R.accountId()=='17','a saved device token survives app restarts and the legacy 30-day expiry')
status=nil;body=nil
check(not R.open() and R.signedIn(),'being offline does not remove the stored login')
status=503;body='{}'
check(not R.open() and R.signedIn(),'service downtime keeps the same device credentials')
package.loaded['src.core.SaveData']={persistenceFs=function() return fs end}
local policy=require('src.storage.AccountStorage');policy.enable()
files[policy.FILE]=S.encode({schema=1,accountId='17'})
status=401;body='{}'
check(not R.open() and not R.signedIn() and not R.accessToken(),'server revocation removes online access')
check(R.accountId()=='17' and not files[R.FILE]:find(token,1,true),'revocation keeps the local account namespace while removing its token')
R=fresh();check(not R.signedIn() and R.accountId()=='17','a restart after revocation still preserves offline save ownership')
check(policy.scope()=='17' and policy.saveCheck(),'the running save policy keeps the same account scope after remote revocation')
assert(R.acceptConnection({access_token=token,expires_in=3600,email='fixture@example.test',account_id='17'}))
local newer=string.rep('b',64)
assert(R.acceptConnection({access_token=newer,expires_in=3600,email='second@example.test',account_id='18'}))
R.expire(token)
check(R.signedIn() and R.accountId()=='18','late revocation of an old token cannot disconnect a newer login')
check(not R.acceptAccount({account_id='17',email='wrong@example.test'}) and R.accountId()=='18','a mismatched account response cannot reassign stored device credentials')
status=200;R.signOut()
check(not fresh().signedIn() and not files[R.FILE],'explicit sign-out remains signed out after restarting')
print('Persistent device session: '..n..' checks passed')
