package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local account='17';local current=1000;local oldTime=os.time;os.time=function() return current end
package.loaded['src.cloud.RetroCloud']={accountId=function() return account end,signedIn=function() return account~=nil end}
local created,cancelled=0,0;local response={account_id='17',friends={{nickname='Fixture',online=true}}}
package.loaded['src.cloud.NativeAccount']={friends=function() return response end}
package.loaded['src.cloud.Task']={new=function(fn) created=created+1;return {poll=function() return {kind='done',first=fn()} end,cancel=function() cancelled=cancelled+1 end} end}
local P=require('src.cloud.Presence');local n=0;local function check(v,m) assert(v,m);n=n+1 end
P.tick();P.tick();check(P.read().friends[1].online and created==1,'the shared presence request caches the current account friend list')
for i=1,20 do P.tick() end
check(created==1,'presence polls are bounded rather than sent every rendered frame')
current=current+45;P.tick();check(created==2,'an active game can refresh its account presence every 45 seconds')
account='18';P.tick()
check(cancelled==1 and not P.read(),'changing accounts cancels the old request and hides its private friend cache immediately')
response={account_id='17',friends={}};P.tick();check(not P.read(),'a late response for another account cannot replace the new account profile')
P.accept({account_id='18',friends={}});check(P.read().account_id=='18','a current-account UI action updates the same presence cache')
account=nil;P.tick();check(not P.read(),'explicit sign-out removes locally cached presence')
os.time=oldTime
print('Account presence: '..n..' checks passed')
