package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local Json=require('src.link.Json')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local token,accepted,expired
package.loaded['src.cloud.RetroCloud']={API='https://pokexpert.de/api/cloud/v1',accessToken=function() return token end,
  acceptConnection=function(doc) accepted=doc.access_token;return true end,expire=function() expired=true end}
love.system={getOS=function() return 'OS X' end}
local response={version='test-policy'};local code=200;local sent
package.loaded['src.cloud.Http']={request=function(m,u,o) sent={method=m,url=u,opts=o};return code,Json.encode(response) end}
local A=require('src.cloud.NativeAccount')
check(A.policy().version=='test-policy','policies are readable before connecting a device')
response={state='email_code',challenge=string.rep('a',64)};code=202
check(A.register({email='fixture@example.test',password='not-a-real-password'}).challenge==response.challenge,'registration awaits the server email challenge')
check(sent.opts.sensitive and Json.decode(sent.opts.body).label=='RetroRecomped · OS X','native auth uses private transport and identifies this device')
response={state='connected',access_token=string.rep('b',64),email='fixture@example.test',expires_in=3600};code=200
local doc=A.login('fixture@example.test','fixture')
check(accepted==string.rep('b',64) and doc.access_token==nil,'only the token store receives an access token, never the UI document')
code=422;response={errors={password={'Choose a longer password.'}}}
local _,why=A.reset(string.rep('a',64),'12345678','short','short');check(why=='Choose a longer password.','validation feedback is readable inside the launcher')
code=500;response={message='private exception contents'};_,why=A.forgot('fixture@example.test')
check(not why:find('private',1,true),'server exception details do not reach the account UI')
code=200;response={devices={}};token='my-device-token'
check(A.devices() and sent.opts.headers.Authorization=='Bearer my-device-token','the device list uses the existing cloud identity')
local before=sent;check(not A.revoke('../other') and sent==before,'invalid device identifiers never become request paths')
code=401;response={message='Reconnect'};check(not A.devices() and expired,'expired sessions return to native sign-in')
print('Native account: '..n..' checks passed')
