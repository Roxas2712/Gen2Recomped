package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.system={getOS=function()return 'Windows'end}
local S=require('src.core.SaveSerializer');local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local current=S.encode({player={name='Fixture'},meta={playthroughId='fixture'},playTime=120})
local readProblem;local slots={{id='slot1',name='Fixture'}}
package.loaded['src.core.SaveData']={persistenceFs=function()return love.filesystem end,
 readSlotBytes=function()return not readProblem and current or nil,readProblem end,
 slotDiskPath=function()error('raw Windows path must not be opened')end,
 listSlots=function()return slots end,peekSlot=function()return S.decode(current)end}
local order,states={},0;local normalDone=false
package.loaded['src.storage.SuspendStore']={sync=function()order[#order+1]='exact';check(normalDone,'normal saves acknowledge before exact state');error('Exact transfer unavailable')end}
local C=require('src.import.CloudSync');C.loadState=function()return {device='fixture',links={}}end
C.saveState=function()states=states+1;return true end
local objects={};local fail
local store={kind='retro',read=function(p)return objects[p]end,list=function()return{}end,
 write=function(p,b)order[#order+1]='write';if fail then return false,'Storage quota reached'end;objects[p]=b;return true end}
local result=C.syncOne(store,'red','slot1',true,function()normalDone=true end)
check(result.normal=='uploaded' and result.suspendNotice:find('unavailable',1,true),'exact failure cannot erase normal upload acknowledgement')
local prior=#order;local normal=C.syncOne(store,'red','slot1',true,nil,true)
check(normal=='uploaded' and order[#order]~='exact','normal-only save never attempts an exact checkpoint')
check(objects['saves/red/fixture-slot1.lua']==current and states==2,'normal bytes and link state are durable before exact failure')
local Sync=require('src.storage.SyncStatus');check(Sync.result(result).state=='partial','UI distinguishes saved progress from unfinished exact transfer')
normalDone=false;order={};slots={{id='slot1'},{id='slot2'}}
local tally=C.syncVersions(store,{'red'},function(t)normalDone=true;check(t.uploaded==2,'all normal slots precede exact transfers')end)
check(tally.failed==0 and tally.suspendFailed==2,'exact failures have a separate tally')
check(Sync.result(tally).state=='partial','batch preserves normal success with exact warnings')
fail=true;normalDone=true
local failed=C.syncVersions(store,{'red'})
check(failed.failed==2 and failed.problem=='Storage quota reached','failed normal uploads retain the real reason')
check(Sync.result(failed).state=='error','a real save failure never becomes partial success')
readProblem='Folder access denied';local value,why=C.syncSlot(store,{device='fixture',links={}},'red','slot1')
check(not value and why==readProblem,'an unreadable local file is not treated as an empty slot')
check(Sync.describe(Sync.get()):find('failed',1,true),'failed UI names failure instead of unexplained paused')
package.loaded['src.core.SaveData']=nil
local Actual=require('src.core.SaveData');local fs=Actual.persistenceFs()
fs.write('saves/red/slot1.lua',current)
check(Actual.readSlotBytes('red','slot1')==current,'real SaveData reads the scoped filesystem bytes')
check(not Actual.readSlotBytes('red','../slot1'),'raw slot reads reject traversal')
Sync.result('uploaded',nil,'red','slot1')
local changed=S.decode(current);changed.playTime=121;local changedBytes=S.encode(changed)
assert(Actual.commitSave(fs,'saves/red/slot1.lua','saves/red/slot1.lua.bak',changedBytes,changed))
check(Sync.get('red','slot1').state=='local','new local progress invalidates a previous green cloud badge')
Sync.result('uploaded',nil,'red','slot1')
assert(Actual.commitSave(fs,'saves/red/slot1.lua','saves/red/slot1.lua.bak',changedBytes,changed))
check(Sync.get('red','slot1').state=='available','writing identical bytes does not create a false pending upload')
print('Cloud save feedback: '..checks..' checks passed')
