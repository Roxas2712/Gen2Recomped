-- ROM-free protocol regression suite. Run with Lua or LuaJIT.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local Duel=require('src.pinball.Duel')
local Net=require('src.link.Net')
local rules={rom='USA-sha1',backend='build-v1',content='base',field=0,frames=18000,seed=0}
local function pair(other)
 local a,b=Net.loopbackPair()
 local x,y=Duel.new(a,true,rules),Duel.new(b,false,other or rules)
 x:update();y:update();x:update()
 return x,y,a,b
end
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function start(x,y)
 check(x.state=='lobby' and y.state=='lobby','hello handshake')
 check(x:ready(string.rep('a',40)) and y:ready(string.rep('a',40)),'both players ready')
 x:update();y:update();x:update()
 check(x.state=='playing' and y.state=='playing','host start after both ready')
end
local x,y,a,b=pair();start(x,y)
check(x:progress(120,25000,false),'first score')
y:update();check(y.remoteScore==25000 and y.remoteFrame==120,'live score delivery')
check(not x:progress(119,26000,false),'local frame regression rejected')
check(not x:progress(121,24999,false),'local score regression rejected')
check(x:progress(18000,999999999999,true),'12 digit score stays exact')
y:update();check(y.remoteScore==999999999999,'12 digits over JSON')
check(y:progress(18000,10,true),'other player finishes');x:update()
check(x.result=='win' and y.result=='loss','consistent final result')
x,y=pair();start(x,y)
x:progress(18000,700,true);y:progress(18000,700,true);x:update();y:update()
check(x.result=='draw' and y.result=='draw','ties are draws')
local changed={};for k,v in pairs(rules)do changed[k]=v end;changed.content='modded'
x,y=pair(changed);check(x.state=='cancelled' and y.state=='cancelled','different content rejected')
x,y,a,b=pair();start(x,y)
a:send{type='pinball_duel',protocol=1,kind='score',seq=1,frame=18001,score='1',done=true}
y:update();check(y.state=='cancelled' and not y.result,'out-of-budget frame rejected')
x,y,a,b=pair();start(x,y)
a:send{type='pinball_duel',protocol=1,kind='score',seq=1,frame=10,score='-1',done=false}
y:update();check(y.state=='cancelled','negative score rejected')
x,y,a,b=pair();start(x,y)
x:close();y:update();check(y.state=='cancelled' and not y.result,'graceful cancellation awards no winner')
x,y,a,b=pair();start(x,y)
b.closed=true;y:update();check(y.state=='cancelled' and not y.result,'transport failure awards no winner')
x,y=pair();check(x:ready(string.rep('a',40)) and y:ready(string.rep('b',40)),'different checkpoint setup')
x:update();y:update();check(x.state=='cancelled' and y.state=='cancelled','different initial guest RAM rejected')
print(checks..' Pinball duel checks passed')
