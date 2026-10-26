package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.keyboard={setTextInput=function()end,isDown=function()return false end}
local signed=true;local n=0;local function check(v,m)assert(v,m);n=n+1 end
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return signed and '1' or nil end,nickname=function()return 'Owner'end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()return {kind='done',first=fn()}end,cancel=function()Cancelled=true end}end}
local sent
local doc={account_id='1',preferences={requests_enabled=true,visibility_enabled=true,friends={}},friends={{account_id='2',nickname='Friend',online=true,friend_tag='Friend#1234',playing={{device='11111111-1111-4111-8111-111111111111',edition='crystal',compatible=true,available=true}}}},invites={{id='22222222-2222-4222-8222-222222222222',nickname='Friend',mode='trade',edition='crystal',incoming=true,state='pending'}}}
package.loaded['src.cloud.Play']={read=function()return doc end,refresh=function()end,request=function(method,path,payload)sent={method,path,payload};return {account_id='1',preferences=doc.preferences}end}
package.loaded['src.cloud.Presence']={read=function()return doc end}
package.loaded['src.cloud.NativeAccount']={profile=function()return {name='Owner',friend_tag='Owner#1111'}end}
local F=require('src.ui.FriendsMenu');local O={page='home'}
check(F.action(O,'friends') and O.page=='friends','native Friends tab opens without leaving the game')
F.tick(O);F.tick(O);check(O.socialProfile.friend_tag=='Owner#1111','native profile loads the shared nickname and friend tag')
local rows=F.rows(O);local found={};for _,r in ipairs(rows)do found[r.id]=r end
check(found['acceptLink:22222222-2222-4222-8222-222222222222'] and found['declineLink:22222222-2222-4222-8222-222222222222'],'incoming invitation offers both accept and decline')
F.action(O,'allRequests');F.tick(O);check(sent[2]=='preferences' and sent[3].requests_enabled==false,'global invitation switch updates the shared account preference')
F.action(O,'friend:2');rows=F.rows(O);found={};for _,r in ipairs(rows)do found[r.id]=r end
check(found['pref:visible:2'] and found['pref:requests:2'],'each accepted friend has separate visibility and invitation controls')
check(found['invite:battle:11111111-1111-4111-8111-111111111111'] and found['invite:trade:11111111-1111-4111-8111-111111111111'],'talk menu offers edition-specific native battles and trades')
F.action(O,'pref:visible:2');F.tick(O);check(sent[3].friend_id==2 and sent[3].visible==false,'excluding a friend targets the account, rather than an ephemeral device')
F.action(O,'declineLink:22222222-2222-4222-8222-222222222222');F.tick(O);check(sent[3].accept==false,'decline cannot accidentally accept an incoming request')
F.action(O,'friendTag');F.text(O,'Jörg');F.key(O,'backspace');F.key(O,'return');check(O.friendQuery=='Jör','friend search preserves Unicode while editing')
O.socialJob={cancel=function()Cancelled=true end};F.clear(O);check(Cancelled and not O.friendFocus,'closing owns and cancels pending UI work and text input')
signed=false;rows=F.rows(O);check(#rows==2 and rows[2].id=='library','guests keep local play and receive a clear optional sign-in entry')
print('Native friends menu: '..n..' checks passed')
