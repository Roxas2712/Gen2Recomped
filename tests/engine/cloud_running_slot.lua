package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local S=require('src.core.SaveSerializer')
local current=S.encode({player={name='Current'},playTime=120})
local remote=S.encode({player={name='Other device'},playTime=130})
local writes={}
local suspendCalls=0
package.loaded['src.storage.SuspendStore']={sync=function()
 suspendCalls=suspendCalls+1;return nil,'legacy save has no playthrough identity'
end}
package.loaded['src.core.SaveData']={slotDiskPath=function() return '/test/running' end,
 listSlots=function() return {{id='running',name='Current'}} end,createSlot=function() return 'cloud-copy' end,
 writeSlot=function(_,id,value) writes[id]=value;return true end,renameSlot=function() end,
 peekSlot=function(version,slot)
  check(version=='red' and slot=='running','suspend preflight inspects the selected running slot')
  return S.decode(current)
 end}
local originalOpen=io.open
io.open=function(path,mode)
 if path=='/test/running' then return {read=function() return current end,close=function() end} end
 return originalOpen(path,mode)
end
local C=require('src.import.CloudSync')
local state={device='device',links={red={running={cloudId='linked',hash=C.hash(current)}}}}
local objects={['saves/red/linked.lua']=remote}
local store={kind='retro',profileScope='retro:one@example.invalid',read=function(p) return objects[p] end,
 write=function(p,b) objects[p]=b;return true end,list=function() return {} end}
check(C.syncSlot(store,state,'red','running',true)=='kept both','uploading a running game keeps a competing cloud branch')
check(not writes.running and writes['cloud-copy'].player.name=='Other device','remote progress is imported as a new slot and never replaces the running slot')
check(objects['saves/red/linked.lua']==current and objects['backups/red/linked.1.lua']==remote,'the current game uploads while the previous cloud copy remains backed up')
local keys={};C.loadState=function(key) keys[#keys+1]=key;return {device='device',links={}} end;C.saveState=function() end
C.syncOne(store,'red','running',true)
store.profileScope='retro:two@example.invalid';C.syncOne(store,'red','running',true)
check(keys[1]~=keys[2],'different ModCompass accounts never reuse one another’s save links')
check(suspendCalls==0,'legacy saves without a playthrough identity do not sync suspend data')
io.open=originalOpen
print('Running-slot cloud: '..n..' checks passed')
