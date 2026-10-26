package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local account='1';local clock=10;love.timer.getTime=function()return clock end
package.loaded['src.cloud.RetroCloud']={signedIn=function()return account~=nil end,accountId=function()return account end}
package.loaded['src.cloud.NativeAccount']={request=function()return {account_id='1'}end}
local cancelled=0;local response
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()local a,b=fn();return {kind='done',first=a,second=b}end,cancel=function()cancelled=cancelled+1 end}end}
local blocked=false;local starts=0
package.loaded['src.link.FriendLink']={tick=function()return blocked end,start=function()starts=starts+1;return true end}
package.loaded['src.link.CloudNet']={pump=function()end}
package.loaded['src.cloud.Presence']={accept=function()end}
package.loaded['src.link.Handshake']={hello=function()return {fingerprint='abcdefgh'}end,onlineAllowed=function()return true end}
package.loaded['src.core.GameVersion']={get=function()return 'crystal'end}
local world={map={id='MAP'},player={px=32,py=48,facing='up'},scriptMoves={},runner={isRunning=function()return false end}}
local game={data={},save={},overworld=world,stack={top=function()return nil end,active=function()return world end}}
local P=require('src.cloud.Play')
check(P.context(game).available,'Gen2 persistent world uses stack.active rather than requiring the world to be a menu')
check(P.context(game).position.x==32,'presence reports only position and native compatibility')
game.stack.active=function()return {}end;check(not P.context(game).available,'menus or battles cannot accept a link invitation');game.stack.active=function()return world end
world.runner.isRunning=function()return true end;check(not P.context(game).available,'a running script cannot be interrupted by friend play');world.runner.isRunning=function()return false end
world.transitioning=true;check(not P.context(game).available,'map transitions cannot accept a link');world.transitioning=nil
game.linkSession=true;check(not P.context(game).available,'an existing native link cannot be replaced');game.linkSession=nil
local calls=0;local payload
P.request=function(method,path,v)calls=calls+1;payload=v;return response end
response={account_id='1',friends={},invites={{id='session',mode='battle',state='accepted'}}}
P.tick(game);P.tick(game)
check(starts==1 and payload.position.map=='MAP','an accepted invitation enters the current game via the native link adapter')
clock=clock+1;P.tick(game);P.tick(game);check(starts==1,'repeated presence cannot enter the same link twice')
check(P.read()==response,'own account presence is readable while fresh')
clock=clock+16;check(not P.read(),'stale network positions expire instead of lingering as figures')
P.tick(game);account='2';P.tick(game);check(cancelled==1 and not P.read(),'account switch cancels in-flight requests and drops old private positions')
account=nil;P.tick(game);check(not P.read(),'guest play has no friend position data')
print('Friend presence and native entry: '..n..' checks passed')
