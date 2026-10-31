-- Real isolated HTTPS server required; no production credentials or ROMs.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.system={getOS=function()return 'OS X'end}
local J=require('src.link.Json');local S=require('src.core.SaveSerializer')
local cfg=assert(io.open(assert(os.getenv('CLOUD_SAVE_QA_CONFIG')),'rb'));local c=J.decode(cfg:read('*a'));cfg:close()
assert(c.url:match('^https://localhost:%d+/api/cloud/v1$'))
local root=c.profile
local fs={}
function fs.read(p)local f=io.open(root..'/'..p,'rb');if not f then return end;local b=f:read('*a');f:close();return b end
function fs.write(p,b)local f,e=io.open(root..'/'..p,'wb');if not f then return false,e end;f:write(b);f:close();return true end
function fs.getInfo(p)local f=io.open(root..'/'..p,'rb');if f then local n=f:seek('end');f:close();return{type='file',size=n}end end
function fs.remove(p)return os.remove(root..'/'..p)end
function fs.rename(a,b)return os.rename(root..'/'..a,root..'/'..b)end
function fs.createDirectory()return true end
function fs.getSaveDirectory()return root end
love.filesystem=fs
local name='saves/red/slot1.lua'
local saves={persistenceFs=function()return fs end,readSlotBytes=function()return fs.read(name)end,
 listSlots=function()return fs.read(name)and{{id='slot1',name='HTTPS fixture'}}or{}end,
 peekSlot=function()return S.decode(fs.read(name)or'')end,createSlot=function()return 'slot1'end,
 renameSlot=function()return true end,writeSlot=function(_,_,save)return fs.write(name,S.encode(save))end}
package.loaded['src.core.SaveData']=saves
local options={cloudAutoSync=true,cloudService='retro'}
saves.loadOptions=function()return options end
local R=require('src.cloud.RetroCloud');R.API=c.url
R.accessToken=function()return c.token end;R.accountId=function()return c.account end;R.account=function()return c.account..'@example.invalid'end
R.signedIn=function()return true end;R.registrationStatus=function()return'approved'end
local C=require('src.import.CloudSync');local Sync=require('src.storage.SyncStatus')
local store,problem=R.open()
if c.mode=='revoked' then
 assert(not store and problem:find('Sign in again',1,true));print('Cloud HTTPS revoked-session check passed');return
end
assert(store,problem)
if c.mode=='foreign' then
 assert(#store.list('saves/red')==0,'foreign account can see another account save');print('Cloud HTTPS foreign-account check passed');return
end
if c.mode=='auto-offline' or c.mode=='auto-retry'then
 -- The queue schedules actual HTTPS requests, using a headless task runner.
 -- This does not qualify native LOVE workers or a Windows OS.
 package.loaded['src.core.GameVersion']={ORDER={'red'},info=function(v)return v=='red'and{}end}
 package.loaded['src.cloud.Task']={new=function(fn)return{cancel=function()end,poll=function()local a,b=fn();return{kind='done',first=a,second=b}end}end}
 local now=0;love.timer.getTime=function()return now end
 local O=require('src.storage.CloudOutbox')
 if c.mode=='auto-offline'then
  assert(fs.write(name,S.encode({player={name='Automatic'},playTime=240})))
  assert(O.changed('red','slot1'))
  local H=require('src.cloud.Http');local request=H.request
  H.request=function()return nil,'Offline fixture'end
  now=2;O.tick();now=4;O.tick();H.request=request
  local pending=S.decode(assert(fs.read(O.FILE))).pending['red/slot1']
  assert(pending and pending.attempts==1 and Sync.get('red','slot1').state=='error')
 else
  assert(S.decode(assert(fs.read(O.FILE))).pending['red/slot1'],'pending journal lost across client restart')
  O.retry();now=2;O.tick();now=4;O.tick()
  assert(not S.decode(assert(fs.read(O.FILE))).pending['red/slot1'],'automatic retry did not acknowledge the real HTTPS upload')
  assert(Sync.get('red','slot1').state=='available')
 end
elseif c.mode=='upload' or c.mode=='partial' then
 local save={player={name=c.mode=='partial'and'Updated'or'HTTPS'},meta={playthroughId='https-fixture'},playTime=c.mode=='partial'and 180 or 120}
 assert(fs.write(name,S.encode(save)))
 if c.mode=='partial' then package.loaded['src.storage.SuspendStore']={sync=function()error('Injected exact-transfer failure')end}end
 local result,why=C.syncOne(store,'red','slot1',true,nil,c.mode~='partial');assert(result,why)
 assert(Sync.result(result).state==(c.mode=='partial'and'partial'or'available'))
else
 local result,why=C.restoreVersions(store,{'red'});assert(result,why)
 local restored=assert(saves.peekSlot());assert(restored.player.name==c.expected,'restored save differs')
end
print('Cloud HTTPS '..c.mode..' check passed')
