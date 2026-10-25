package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local account='one@example.invalid';local expired=false
package.loaded['src.cloud.RetroCloud']={API='https://pokexpert.de/api/cloud/v1',account=function() return account end,accessToken=function() return 'private-token' end,expire=function() expired=true end}
local Json=require('src.link.Json')
local response={account={id=1,name='Author',email=account},repository='author/mod',verified=false,proof=Json.encode({service='modcompass',account=1,nonce='public-proof'})}
local status=200;local sent={}
local Http=require('src.cloud.Http')
Http.request=function(method,url,opts) sent[#sent+1]={method=method,url=url,opts=opts};return status,Json.encode(response) end
local D=require('src.cloud.DeveloperAccount')
local profile=assert(D.profile())
check(sent[1].url=='https://pokexpert.de/api/cloud/v1/developer' and sent[1].opts.headers.Authorization=='Bearer private-token','developer profile uses the same authenticated account API as saves')
check(D.read().repository=='author/mod','the last developer state remains available locally')
local url=D.proofUrl(profile)
check(url:find('https://github.com/author/mod/new/HEAD?',1,true)==1 and url:find('filename=',1,true),'GitHub setup opens a prepared proof file without any GitHub credential')
response.proof=nil;check(D.profile().proof~=nil,'refreshing a pending claim preserves the prepared proof for that account and repository')
response.repository='author/another';check(not D.profile().proof,'a different repository never inherits the previous proof')
account='two@example.invalid';check(not D.read(),'switching accounts hides the previous private developer cache')
response.account.id=2;response.account.email=account;D.save('author/another')
check(sent[#sent].method=='PUT' and Json.decode(sent[#sent].opts.body).repository=='author/another','native repository edits use the authenticated developer endpoint')
response.verified=true;check(D.verify().verified and sent[#sent].url:find('/developer/verify',1,true),'verification refreshes the server-confirmed shared profile')
response.repository='../private';check(not D.profile(),'invalid repository identities never become local GitHub links')
response={message='Reconnect this device.'};status=401
check(not D.profile() and expired,'revoked tokens return the native UI to connection setup')
print('Developer account: '..n..' checks passed')
