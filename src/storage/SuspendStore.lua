-- Immutable, bounded suspend blocks use the existing private account store.
-- Local guest suspends never contact a cloud service.
local M={BLOCK=512*1024,MAX_BYTES=24*1024*1024}
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local Safety=require('src.core.SaveSafety')
local function hash(b)return love.data.encode('string','hex',love.data.hash('sha256',b))end
local function digest(v)return type(v)=='string' and #v==64 and v:match('^[a-f0-9]+$')end
local function identity(v)return type(v)=='string' and #v>0 and #v<=80 and v:match('^[%w_%-]+$')end
local function path(version,id)
 if not require('src.core.GameVersion').info(version) or not identity(id) then return nil end
 return 'states/local/'..version..'/'..id..'.lua'
end
local function parse(b,limit)
 if type(b)~='string' or #b>(limit or M.MAX_BYTES) then return nil end
 return S.decode(b)
end
local function atomic(fs,p,bytes)
 return Safety.atomicWrite(fs,p,bytes,{decode=S.decode})
end
function M.keep(game)
 local permitted,why=require('src.storage.AccountStorage').saveCheck();if not permitted then return nil,why end
 local value,err=require('src.core.SuspendJournal').capture(game);if not value then return nil,err end
 local slot=Saves.activeSlot(value.edition)
 local normal=slot and Saves.peekSlot(value.edition,slot)
 if not normal or not normal.meta or normal.meta.playthroughId~=value.anchor.identity.playthroughId then return nil,'Save normal game progress once before creating a portable suspend.' end
 value.normal=hash(S.encode(normal))
 local bytes=S.encodeExact(value);local p=path(value.edition,value.anchor.identity.playthroughId)
 if not p then return nil,'Invalid suspend identity.' end
 local fs=Saves.persistenceFs()
 local ok,problem=atomic(fs,p,bytes);if not ok then return nil,problem end
 -- Normal progress remains a separate, emulator-compatible save. A suspend
 -- never writes the battle's temporary state into the battery-save slot.
 return true
end
function M.matchesNormal(value,version,slot)
 local normal=Saves.peekSlot(version,slot)
 return normal and value.normal==hash(S.encode(normal)) or false
end
function M.read(version,id,fs)
 local p=path(version,id);if not p then return nil,'Invalid suspend identity.' end
 local value=parse((fs or Saves.persistenceFs()).read(p))
 if not value then return nil,'No readable suspend is stored for this playthrough.' end
 if value.schema~=1 or value.edition~=version or not value.anchor or not value.anchor.identity or value.anchor.identity.playthroughId~=id then return nil,'Suspend identity differs from the selected playthrough.' end
 return value
end
function M.has(version,id,fs)
 local p=path(version,id);return p and (fs or Saves.persistenceFs()).getInfo(p)~=nil or false
end
local function validManifest(m,version,id)
 if type(m)~='table' or m.schema~=1 or m.edition~=version or m.playthrough~=id or type(m.bytes)~='number'
  or m.bytes<1 or m.bytes>M.MAX_BYTES or m.bytes%1~=0 or type(m.blocks)~='table' or #m.blocks~=math.ceil(m.bytes/M.BLOCK) then return false end
 for _,b in ipairs(m.blocks)do if not digest(b)then return false end end
 return true
end
local function package(bytes,version,id)
 local manifest={schema=1,edition=version,playthrough=id,bytes=#bytes,blocks={}};local blocks={}
 for i=1,#bytes,M.BLOCK do
  local raw=bytes:sub(i,i+M.BLOCK-1)
  local body=S.encode({schema=1,data=raw});local key=hash(body)
  manifest.blocks[#manifest.blocks+1]=key;blocks[key]=body
 end
 local body=S.encode(manifest);return hash(body),body,blocks
end
function M.sync(store,version,id,pushOnly,fs)
 local allowed,why=require('src.storage.AccountStorage').storeCheck(store);if not allowed then return nil,why end
 if not store or store.kind~='retro' then return nil,'Suspend sync uses your private RetroRecomped account.' end
 local p=path(version,id);if not p then return nil,'Invalid suspend identity.' end
 fs=fs or Saves.persistenceFs()
 local bytes=fs.read(p);if bytes and #bytes>M.MAX_BYTES then return nil,'Local suspend exceeds the transfer limit.' end
 local localId,manifest,blocks
 if bytes then
  if not M.read(version,id,fs)then return nil,'Local suspend needs recovery; cloud was preserved.'end
  localId,manifest,blocks=package(bytes,version,id)
 end
 local info=parse(fs.read(p..'.info.lua'),4096)or {};local base=info.base
 local headPath='states/heads/'..version..'/'..id..'.lua'
 local headBytes=store.read(headPath);local head=headBytes and parse(headBytes,4096)
 if headBytes and (not head or head.schema~=1 or not digest(head.manifest))then return nil,'Cloud suspend head needs recovery.'end
 local remote=head and head.manifest
 local function remember(key)
  local ok,err=require('src.storage.AccountStorage').storeCheck(store);if not ok then return nil,err end
  return atomic(fs,p..'.info.lua',S.encode({schema=1,base=key}))
 end
 if localId and localId==remote then local ok,err=remember(remote);return ok and 'unchanged' or nil,err end
 if localId and (not remote or remote==base)then
  for key,body in pairs(blocks)do
   local target='states/blobs/'..key..'.lua';local old=store.read(target)
   if old and old~=body then return nil,'Immutable suspend block conflict.'end
   if not old then local ok,err=store.write(target,body);if not ok then return nil,err end end
   require('src.cloud.Task').yield()
  end
  local target='states/manifests/'..localId..'.lua';local old=store.read(target)
  if old and old~=manifest then return nil,'Immutable suspend manifest conflict.'end
  if not old then local ok,err=store.write(target,manifest);if not ok then return nil,err end end
  allowed,why=require('src.storage.AccountStorage').storeCheck(store);if not allowed then return nil,why end
  local ok,err=store.write(headPath,S.encode({schema=1,manifest=localId}));if not ok then return nil,err end
  ok,err=remember(localId);return ok and 'uploaded' or nil,err
 end
 if remote and (not localId or localId==base)and not pushOnly then
  local manifestBytes=store.read('states/manifests/'..remote..'.lua')
  if not manifestBytes or hash(manifestBytes)~=remote then return nil,'Cloud suspend manifest fingerprint differs.'end
  local m=parse(manifestBytes,32768);if not validManifest(m,version,id)then return nil,'Invalid cloud suspend manifest.'end
  local parts={}
  for i,key in ipairs(m.blocks)do
   local body=store.read('states/blobs/'..key..'.lua')
   if not body or #body>4*M.BLOCK or hash(body)~=key then return nil,'Cloud suspend block fingerprint differs.'end
   local b=parse(body,4*M.BLOCK);local expected=math.min(M.BLOCK,m.bytes-(i-1)*M.BLOCK)
   if not b or b.schema~=1 or type(b.data)~='string' or #b.data~=expected then return nil,'Invalid cloud suspend block.'end
   parts[#parts+1]=b.data;require('src.cloud.Task').yield()
  end
  local incoming=table.concat(parts);local value=parse(incoming)
  if not value or value.schema~=1 or value.edition~=version or not value.anchor or not value.anchor.identity or value.anchor.identity.playthroughId~=id then return nil,'Cloud suspend belongs to a different playthrough.'end
  allowed,why=require('src.storage.AccountStorage').storeCheck(store);if not allowed then return nil,why end
  local ok,err=atomic(fs,p,incoming);if not ok then return nil,err end
  ok,err=remember(remote);return ok and 'downloaded' or nil,err
 end
 if not localId and not remote then return 'absent' end
 if pushOnly and not localId then return 'absent' end
 return nil,'Both devices have different suspends. Both copies were preserved; choose which one to continue.'
end
return M
