package.path='./?.lua;'..package.path
local now=0;local wall=1000;local id='17';local signed=true;local sent={}
love={timer={getTime=function()return now end}}
os.time=function()return wall end
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return id end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()return {kind='done',first=fn()}end,cancel=function()end}end}
package.loaded['src.cloud.NativeAccount']={presence=function(payload)sent[#sent+1]=payload;return {account_id=id,visible=true,status=payload.state}end}
package.loaded['src.ui.ProfileAvatar']={decode=function()return nil end}
local B=require('src.cloud.AccountBadge')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
B.tick();B.tick()
check(#sent==1 and sent[1].state=='online','a signed-in account starts an online heartbeat')
now=299;wall=1010;B.tick();check(B.state()=='online','idle threshold is five minutes')
now=300;B.tick();B.tick()
check(#sent==2 and sent[2].state=='away','away transition sends immediately without waiting for the next heartbeat')
wall=1041;now=331;B.tick();B.tick()
check(sent[#sent].state=='away','background polling does not count as user input')
B.activity();wall=1042;B.tick();B.tick()
check(sent[#sent].state=='online','input resumes online immediately')
B.acceptPresence({account_id=id,visible=false,status='online'})
check(B.presence.visible==false,'invisible is independent of input activity')
B.accept({account_id=id,name='Fixture'},'image');id='18';B.tick()
check(B.profile==nil and B.image==nil and B.presence==nil,'changing accounts clears cached profile and visibility')
B.acceptPresence({account_id='17',visible=false})
check(B.presence==nil,'a stale response cannot change the new account')
B.counts={account_id=id,online_count=7};B.countAt=wall;id='19';B.accept({account_id=id,name='New fixture'})
check(B.profile.name=='New fixture' and B.counts==nil and B.presence==nil,'a new profile arriving before the next tick also clears the old account cache')
signed=false;B.tick();check(B.read()==nil and B.presence==nil,'signing out clears presence and cached presentation')
print('Account presence: '..n..' checks passed')
