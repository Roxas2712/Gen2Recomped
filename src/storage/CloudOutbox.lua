-- Durable, account-scoped automatic uploads of normal progress only.
-- No network runs inside a save write; in-flight uploads never replace gameplay.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={FILE='cloud_outbox.lua',nextCheck=0,ignored=0}
local S=require('src.core.SaveSerializer')
local function clock()return love.timer.getTime()end
local function deps()
 return require('src.core.SaveData'),require('src.cloud.RetroCloud'),require('src.storage.AccountStorage')
end
local function enabled()
 local saves,auth,policy=deps()
 local options=saves.loadOptions()
 if options.cloudAutoSync~=true or (options.cloudService or 'retro')~='retro' then return end
 if not auth.signedIn() or auth.registrationStatus and auth.registrationStatus()~='approved' then return end
 if not policy.check() then return end
 local id=auth.accountId();if type(id)~='string' or not id:match('^[1-9]%d*$')then return end
 return saves,auth,id
end
local function integer(n)return type(n)=='number'and n==n and n>=0 and n<9007199254740991 and n%1==0 end
local function valid(row,key)
 return type(row)=='table'and type(row.edition)=='string'and require('src.core.GameVersion').info(row.edition)
  and type(row.slot)=='string'and row.slot:match('^slot%d+$')and integer(row.serial)
  and key==row.edition..'/'..row.slot and integer(row.retryAt)and integer(row.attempts)and row.attempts<=100
end
local function state(saves,id)
 local fs=saves.persistenceFs()
 if M.current and M.current.fs==fs and M.current.id==id then return M.current end
 local raw=fs.read(M.FILE);local doc=raw and S.decode(raw)
 if not raw and fs.getInfo(M.FILE)then return nil,'Automatic cloud transfer needs recovery. Local saves are kept.'end
 if raw and (type(doc)~='table'or doc.schema~=1 or doc.account~=id or type(doc.pending)~='table'or not integer(doc.serial))then
  return nil,'Automatic cloud transfer needs recovery. Local saves are kept.'
 end
 doc=doc or{schema=1,account=id,serial=0,pending={}}
 for key,row in pairs(doc.pending)do
  if not valid(row,key)or row.serial>doc.serial then return nil,'Automatic cloud transfer needs recovery. Local saves are kept.'end
  row.retryAt=math.min(row.retryAt,os.time()+300)
 end
 M.current={id=id,fs=fs,doc=doc};return M.current
end
local function persist(st)
 return require('src.core.SaveSafety').atomicWrite(st.fs,M.FILE,S.encode(st.doc),{decode=S.decode})
end
local function enqueue(st,edition,slot)
 local key=edition..'/'..slot
 st.doc.serial=(tonumber(st.doc.serial)or 0)+1
 st.doc.pending[key]={edition=edition,slot=slot,serial=st.doc.serial,changed=os.time(),attempts=0,retryAt=0}
 return persist(st)
end
function M.ensureSlot(edition)
 if M.ignored>0 then return end
 local saves=enabled();if not saves or saves.activeSlot(edition)then return end
 -- A first-ever adventure formerly stayed in the flat legacy file until
 -- restart. Give it a regular destination before the first save is encoded,
 -- preserving its existing playthrough identity and mod namespace.
 local slot,why=saves.createSlot(edition);if not slot then return nil,why end
 return saves.setActiveSlot(edition,slot)
end
function M.changed(edition,slot)
 if M.ignored>0 then return end
 local saves,_,id=enabled();if not saves then return end
 if not require('src.core.GameVersion').info(edition)or type(slot)~='string'or not slot:match('^slot%d+$')then return end
 local st,why=state(saves,id);if not st then return nil,why end
 local ok,err=enqueue(st,edition,slot);M.nextCheck=math.min(M.nextCheck,clock()+.5)
 if not ok then require('src.storage.SyncStatus').set('local',edition,slot,'Saved locally. Automatic upload will retry.')end
 return ok,err
end
function M.applying(fn,...)
 M.ignored=M.ignored+1
 local ok,a,b=pcall(fn,...);M.ignored=M.ignored-1
 if not ok then error(a,0)end;return a,b
end
function M.cancel()
 if M.job then M.job.task:cancel();M.job=nil end
 if M.current then M.current.discovered=false end
 M.nextCheck=0
end
function M.retry(edition,slot)
 local saves,_,id=enabled();if not saves then return end
 local st=state(saves,id);if not st then return end
 st.discovered=false
 for _,row in pairs(st.doc.pending)do
  if not edition or row.edition==edition and(not slot or row.slot==slot)then row.retryAt=0;row.attempts=0 end
 end
 persist(st);M.nextCheck=0
end
local function discover(st,saves,auth)
 local Cloud=require('src.import.CloudSync')
 local linkState=Cloud.loadState(Cloud.stateKey{kind='retro',profileScope=auth.profileScope()})
 for _,edition in ipairs(require('src.core.GameVersion').ORDER)do
  for _,slot in ipairs(saves.listSlots(edition)or{})do
   local bytes=saves.readSlotBytes(edition,slot.id)
   local link=linkState.links[edition]and linkState.links[edition][slot.id]
   if bytes and Cloud.isSave(bytes)and(not link or (link.localHash or link.hash)~=Cloud.hash(bytes))and not st.doc.pending[edition..'/'..slot.id]then
    local ok,why=enqueue(st,edition,slot.id);if not ok then return nil,why end
   end
  end
 end
 st.discovered=true;return true
end
function M.tick(blocked)
 local now=clock()
 if not M.job and now<M.nextCheck then return end
 M.nextCheck=now+1
 if M.job then
  -- Poll workers each frame, but do not re-read/parse options each frame.
  -- Profile changes and the settings switch cancel immediately as well.
  local auth=require('src.cloud.RetroCloud')
  if M.job.id~=auth.accountId()or not auth.signedIn()then M.cancel();return end
  local job=M.job;local result=job.task:poll();if not result then return end
  M.job=nil
  local row=job.st.doc.pending[job.key]
  if not row or row.serial~=job.serial then
   require('src.storage.SyncStatus').set('local',job.edition,job.slot,'New progress is saved on this device. Upload it to update your cloud copy.')
   M.nextCheck=0;return
  end
  local Sync=require('src.storage.SyncStatus')
  if result.kind=='done'and result.first then
   job.st.doc.pending[job.key]=nil
   local ok,why=persist(job.st)
   if not ok then job.st.doc.pending[job.key]=row;row.retryAt=os.time()+30 end
   Sync.result(ok and result.first or nil,why,job.edition,job.slot)
   M.nextCheck=now+.5
  else
   row.attempts=math.min(100,(row.attempts or 0)+1);row.retryAt=os.time()+math.min(300,5*2^math.min(row.attempts-1,6))
   persist(job.st)
   Sync.result(nil,result.error or result.second,job.edition,job.slot)
  end
  return
 end
 local saves,auth,id=enabled()
 if not saves then M.cancel();M.nextCheck=now+2;return end
 if blocked then return end
 local st,why=state(saves,id)
 if not st then require('src.storage.SyncStatus').set('error',nil,nil,why);M.nextCheck=now+30;return end
 if not st.discovered then
  local ok,err=discover(st,saves,auth)
  if not ok then require('src.storage.SyncStatus').set('error',nil,nil,err);return end
 end
 local keys={};for key in pairs(st.doc.pending)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do
  local row=st.doc.pending[key]
  if (row.retryAt or 0)<=os.time()then
   local bytes,problem=saves.readSlotBytes(row.edition,row.slot)
   if not bytes and problem then
    row.retryAt=os.time()+30;persist(st);require('src.storage.SyncStatus').set('error',row.edition,row.slot,problem);return
   elseif not bytes then
    st.doc.pending[key]=nil;if not persist(st)then st.doc.pending[key]=row;row.retryAt=os.time()+30 end
   else
    local serial,edition,slot=row.serial,row.edition,row.slot
    local task,err=require('src.cloud.Task').new(function()
     local store,why=auth.open();if not store then return nil,why end
     return require('src.import.CloudSync').syncOne(store,edition,slot,true,nil,true)
    end)
    if not task then
     row.retryAt=os.time()+30;persist(st);require('src.storage.SyncStatus').set('error',edition,slot,err);return
    end
    M.job={task=task,st=st,id=id,key=key,serial=serial,edition=edition,slot=slot}
    require('src.storage.SyncStatus').set('uploading',edition,slot);return
   end
  end
 end
end
return M
