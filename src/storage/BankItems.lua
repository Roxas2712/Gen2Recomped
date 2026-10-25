-- Held-item custody for Bank copies. Transfers are staged with the save draft
-- and committed together; a failed save never consumes a stored item.
local M={FILE='bank/items.lua'}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local function clone(v) return S.decode(S.encode(v)) end
local function disk() return require('src.core.SaveData').persistenceFs() end
local function hash(s) return love.data.encode('string','hex',love.data.hash('sha256',s)) end
local function id(s) return type(s)=='string' and #s==64 and s:match('^[a-f0-9]+$') end
function M.decode(bytes)
  if type(bytes)~='string' or #bytes>4*1024*1024 then return nil end
  local ok,v=pcall(S.decode,bytes)
  if not ok or type(v)~='table' or v.schema~=1 or type(v.items)~='table' then return nil end
  local n=0
  for key,item in pairs(v.items) do
    n=n+1
    if n>4096 or not id(key) or type(item)~='table' or type(item.item)~='string' and type(item.item)~='number'
      or type(item.canonical)~='string' or not id(item.owner) or not require('src.core.GameVersion').VERSIONS[item.version]
      or type(item.revision)~='number' or item.revision<1 or item.revision%1~=0
      or item.state~='available' and item.state~='assigned' or item.assignedTo and not id(item.assignedTo) then return nil end
  end
  return v
end
function M.load()
  local bytes=disk().read(M.FILE)
  if not bytes then return {schema=1,items={}} end
  return M.decode(bytes), 'Item Bank needs recovery. Existing records were preserved.'
end
function M.custody(origin,item,canonical,version)
  local owner=origin and origin.recordId
  if not id(owner) then return nil end
  return {id=hash(owner..'|'..tostring(item)..'|'..canonical),owner=owner,item=item,canonical=canonical,version=version}
end
function M.returnable(held)
  local inventory=M.load()
  if not inventory or type(held)~='table' or not id(held.id) then return false end
  local item=inventory.items[held.id]
  if item and item.state=='assigned' then return false,'assigned' end
  return not item or item.owner==held.owner and item.state=='available'
end
function M.list()
  local v,why=M.load();if not v then return {},why end
  local out={}
  for key,row in pairs(v.items) do local item=clone(row);item.id=key;out[#out+1]=item end
  table.sort(out,function(a,b) return a.id<b.id end);return out
end
local function update(inventory,mon)
  local carried,problem=require('src.storage.PokemonBank').held(mon);if problem then return nil,problem end
  local held=mon.retroBankHeld
  local owner=mon.retroBankOrigin and mon.retroBankOrigin.recordId
  if held and not carried then
    if not id(held.id) or not id(held.owner) then return nil,'Invalid held-item custody record.' end
    local old=inventory.items[held.id]
    if old and old.state=='assigned' and old.assignedTo~=owner then return nil,'This item is assigned to another Pokémon.' end
    local row=clone(held);row.id=nil;row.state='available';row.assignedTo=nil
    row.revision=old and old.revision or 1
    if old and old.state~='available' then row.revision=row.revision+1 end
    inventory.items[held.id]=row
  end
  local attached=mon.retroBankItem
  if attached and carried then
    local old=inventory.items[attached]
    if not old and mon.retroBankItemRecord and mon.retroBankItemRecord.id==attached then
      old=clone(mon.retroBankItemRecord);old.id=nil;old.state='available';old.revision=1
      inventory.items[attached]=old
    end
    if not old or not id(owner) then return nil,'The held item is missing from your Item Bank.' end
    if old.state=='assigned' and old.assignedTo~=owner then return nil,'This item is already assigned to another Pokémon.' end
    if old.state~='assigned' then old.revision=old.revision+1 end
    old.state='assigned';old.assignedTo=owner
  end
  return true
end
function M.transaction(draft,commit)
  local inventory,why=M.load();if not inventory then return nil,why end
  local previous=disk().read(M.FILE)
  for _,row in ipairs(require('src.storage.PokemonBank').scan(draft,draft.version or 'red')) do
    local ok,err=update(inventory,row.mon);if not ok then return nil,err end
  end
  local bytes=S.encode(inventory)
  if not M.decode(bytes) then return nil,'Invalid Item Bank data. No save was changed.' end
  disk().createDirectory('bank')
  local ok,err=Safety.atomicWrite(disk(),M.FILE,bytes,{decode=M.decode})
  if not ok then return nil,err end
  local ran,result,reason=pcall(commit)
  if not ran or not result then
    -- This function does not yield. Roll back only the exact ledger written
    -- by this transaction; never overwrite an independently changed file.
    if disk().read(M.FILE)==bytes then
      if previous then Safety.atomicWrite(disk(),M.FILE,previous,{decode=M.decode}) else disk().remove(M.FILE) end
    end
    return nil,ran and reason or result
  end
  return result,reason
end
function M.equip(itemId,entry)
  local inventory,why=M.load();if not inventory then return nil,why end
  local item=inventory.items[itemId]
  if not item or item.state~='available' then return nil,'Choose an available item.' end
  local carried,problem=require('src.storage.PokemonBank').held(entry.mon)
  if problem then return nil,problem end
  if carried then return nil,'This Pokémon already holds an item.' end
  local B=require('src.storage.PokemonBank');local data,err=B.data(entry.source.version)
  if not data then return nil,err end
  if require('src.core.GameVersion').generation(entry.source.version)==1 then return nil,'Move this Pokémon to a game with held items before equipping it.' end
  local found
  for key,def in pairs(data.items) do
    local name=tostring(def.name or key):upper():gsub('[^A-Z0-9]','')
    if name==item.canonical then if found then return nil,'Item identity is ambiguous in this game.' end;found=key end
  end
  if not found then return nil,'This item is unavailable in the Pokémon’s source game.' end
  local copy=clone(entry);copy.id=nil
  copy.mon.item=found;copy.mon.heldItem=nil
  copy.mon.retroBankItem=itemId;copy.mon.retroBankHeld=nil
  copy.mon.retroBankOrigin=clone(copy.origin or copy.mon.retroBankOrigin)
  copy.canonical.item=item.canonical
  return M.transaction({version=entry.source.version,party={copy.mon}},function() return B.keep(copy) end)
end
function M.sync(store)
  local before=disk().read(M.FILE);local localState,why=M.load();if not localState then return nil,why end
  local remote=store.read(M.FILE)
  local other
  if remote then other=M.decode(remote) else other={schema=1,items={}} end
  if not other then return nil,'Remote Item Bank is unreadable. Both copies are preserved.' end
  if disk().read(M.FILE)~=before then return nil,'Item Bank changed during sync. Please retry.' end
  for key,item in pairs(other.items) do
    local current=localState.items[key]
    if not current or item.revision>current.revision then localState.items[key]=item
    elseif item.revision==current.revision and S.encode(item)~=S.encode(current) then return nil,'Item assignment conflict between devices. Both copies are preserved.' end
  end
  local bytes=S.encode(localState);local ok,err=store.write(M.FILE,bytes);if not ok then return nil,err end
  if disk().read(M.FILE)~=before then return nil,'Item Bank changed during sync. Please retry.' end
  disk().createDirectory('bank');return Safety.atomicWrite(disk(),M.FILE,bytes,{decode=M.decode})
end
return M
