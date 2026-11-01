-- Durable upload state-machine tests; transport is a controllable fixture.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local now,wall=0,10000
love.timer.getTime=function()return now end
local oldTime=os.time;os.time=function()return wall end
local account='17';local options={cloudAutoSync=true};local permitted=true
local files={};local fs={read=function(p)return files[p]end,write=function(p,b)files[p]=b;return true end,
 getInfo=function(p)return files[p]and{type='file',size=#files[p]}end,remove=function(p)files[p]=nil;return true end}
local bytes='save-one';local unreadable
package.loaded['src.core.SaveData']={persistenceFs=function()return fs end,loadOptions=function()return options end,
 listSlots=function()return{{id='slot1'}}end,readSlotBytes=function()return bytes,unreadable end}
package.loaded['src.core.GameVersion']={ORDER={'red'},info=function(v)return v=='red'and{}end}
package.loaded['src.storage.AccountStorage']={check=function()return permitted end}
local signed=true
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return account end,
 registrationStatus=function()return 'approved'end,profileScope=function()return account end,open=function()return{}end}
local calls=0;local fail,hold,changeDuring;local O
local links={red={slot1={hash=bytes}}}
package.loaded['src.import.CloudSync']={loadState=function()return{links=links}end,stateKey=function()return'fixture'end,
 hash=function(b)return b end,isSave=function(b)return b:match('^save')end,syncOne=function(_,edition,slot,push,_,normal)
  check(edition=='red'and slot=='slot1'and push and normal,'automatic uploads never restore the running slot or sync optional bulk data')
  calls=calls+1
  if hold then coroutine.yield()end
  if changeDuring then changeDuring=false;bytes='save-newer';O.changed('red','slot1')end
  if fail then return nil,'Offline fixture'end
  links.red.slot1.hash=bytes;return'uploaded'
 end}
package.loaded['src.cloud.Task']={new=function(fn)
 local co=coroutine.create(fn)
 return{cancel=function()co=nil end,poll=function()
  local ok,a,b=coroutine.resume(co);assert(ok,a)
  if coroutine.status(co)=='dead'then return{kind='done',first=a,second=b}end
 end}
end}
O=require('src.storage.CloudOutbox')
local function tick(blocked)now=now+2;O.tick(blocked)end
local function pending()local doc=S.decode(files[O.FILE]or'');return doc and doc.pending['red/slot1']end
tick();check(calls==0 and not O.job,'unchanged linked saves do not upload at startup')
O.changed('red','slot1');check(pending(),'normal save enqueue is durable before networking')
tick(true);check(not O.job and calls==0,'restores and manual transfers block new automatic uploads')
fail=true;tick();tick();check(calls==1 and pending().attempts==1,'offline failure retains the local pending save')
tick();check(not O.job,'offline retry has backoff')
O.cancel();O.current=nil;wall=wall+10;fail=false;tick();tick()
check(calls==2 and not pending(),'pending work survives a process restart and clears only after success')
changeDuring=true;O.changed('red','slot1');tick();tick()
check(pending(),'a save made during an upload cannot be acknowledged by the older upload')
tick();tick();check(not pending(),'the newer save receives its own upload')
O.applying(function()O.changed('red','slot1')end);check(not pending(),'remote restore writes do not feed back into the upload queue')
O.changed('red','slot1');options.cloudAutoSync=false;tick();check(not O.job and pending(),'turning sync off keeps pending work without sending it')
options.cloudAutoSync=true;permitted=false;tick();check(not O.job and pending(),'unassigned or foreign profiles never upload in the background')
permitted=true;O.retry();hold=true;tick();tick();check(O.job,'fixture upload is in flight')
signed=false;tick();check(not O.job and pending(),'disconnect cancels in-flight work without losing the journal')
signed=true;hold=false;O.retry();tick();tick()
O.changed('red','slot1');bytes=nil;unreadable='Access denied';tick()
check(pending(),'an unreadable save is retained for recovery rather than dropped')
bytes='save-final';unreadable=nil;O.retry();tick();tick()
options.cloudAutoSync=false;O.cancel();bytes='save-made-while-off';tick()
options.cloudAutoSync=true;O.retry();tick();tick()
check(links.red.slot1.hash==bytes and not pending(),'enabling sync discovers progress saved while automatic uploads were off')
-- Refuse a damaged journal rather than overwriting the recovery evidence.
files[O.FILE]='damaged';O.current=nil;tick()
check(files[O.FILE]=='damaged'and not O.job,'damaged journals stay intact and cannot start an upload')
os.time=oldTime
print('Automatic cloud outbox: '..n..' checks passed (transport fixture)')
