-- Versioned, account-private storage shared by one mod across its games.
-- The public facade never exposes filesystem objects or absolute paths.
local M={VERSION=1,MAX_BYTES=16*1024*1024}
local S=require('src.core.SaveSerializer')
local LuaData=require('src.storage.LuaData')
local Safety=require('src.core.SaveSafety')
local Policy=require('src.storage.AccountStorage')
local function segment(v) return type(v)=='string' and #v<=128 and v:match('^[%w_-]+$') end
local function key(v)
  if type(v)~='string' or #v>240 or v=='' or v:find('//',1,true) or v:sub(1,1)=='/' or v:sub(-1)=='/' then return false end
  for part in v:gmatch('[^/]+') do if not segment(part) then return false end end
  return true
end
local function packageName(v)
  return type(v)=='string' and #v<=96 and v:match('^[%w][%w_.%-]*$') and not v:find('..',1,true)
end
function M.new(modId,injected)
  assert(segment(modId),'Shared storage needs a safe mod ID')
  local account=Policy.scope()
  local function disk()
    local ok,why=Policy.check();if not ok then return nil,why end
    if Policy.enabled and Policy.scope()~=account then return nil,'The shared-storage account changed. Open a new handle.' end
    return require('src.core.SaveData').persistenceFs(injected)
  end
  local root='mod_storage/shared/'..modId
  local packages='bank/packages/'..modId
  local function read(path)
    local fs,why=disk();if not fs then return nil,'account_required',why end
    local info=fs.getInfo(path)
    if info and info.size and info.size>M.MAX_BYTES then return nil,'size_limit' end
    local bytes=fs.read(path);if not bytes then return nil,'not_found' end
    if #bytes>M.MAX_BYTES then return nil,'size_limit' end
    local ok,value=pcall(S.decode,bytes)
    if not ok or type(value)~='table' or not LuaData.inspect(value).serializable then return nil,'invalid_data','Existing bytes were preserved.' end
    return value
  end
  local function put(path,value,immutable)
    local fs,why=disk();if not fs then return nil,'account_required',why end
    if type(value)~='table' then return nil,'invalid_data','Only serializable Lua data tables are accepted.' end
    local bytes,problem=LuaData.encode(value,M.MAX_BYTES)
    if not bytes then return nil,'invalid_data',problem end
    local previous=fs.read(path)
    if immutable and previous and previous~=bytes then return nil,'already_exists','Choose a new export name; the existing package was preserved.' end
    fs.createDirectory(path:match('^(.*)/[^/]+$'))
    local written,err=Safety.atomicWrite(fs,path,bytes,{bak=not immutable and path..'.bak' or nil,decode=Safety.decodeAny})
    if written then return true,nil,{bytes=#bytes} end
    return nil,'write_failed',err
  end
  local api={version=M.VERSION}
  function api:context() return {schema=1,modId=modId,accountId=account,scope='account_shared'} end
  function api:read(name) if not key(name) then return nil,'invalid_key' end;return read(root..'/'..name..'.lua') end
  function api:write(name,value) if not key(name) then return nil,'invalid_key' end;return put(root..'/'..name..'.lua',value) end
  function api:delete(name)
    if not key(name) then return nil,'invalid_key' end
    local fs,why=disk();if not fs then return nil,'account_required',why end
    for _,suffix in ipairs({'.lua','.lua.bak','.lua.tmp'}) do fs.remove(root..'/'..name..suffix) end
    for _,suffix in ipairs({'.lua','.lua.bak','.lua.tmp'}) do if fs.getInfo(root..'/'..name..suffix) then return nil,'delete_failed','The record could not be removed.' end end
    return true
  end
  function api:exportPackage(name,value)
    if not packageName(name) then return nil,'invalid_name' end
    local ok,code,receipt=put(packages..'/'..name..'.lua',value,true)
    if ok then receipt.name=name;receipt.modId=modId end
    return ok,code,receipt
  end
  function api:importPackage(name) if not packageName(name) then return nil,'invalid_name' end;return read(packages..'/'..name..'.lua') end
  function api:listPackages()
    local fs,why=disk();if not fs then return nil,'account_required',why end
    local rows={}
    for _,file in ipairs(fs.getDirectoryItems(packages) or {}) do local name=file:match('^(.*)%.lua$')
      if name and packageName(name) then rows[#rows+1]={name=name} end
    end
    table.sort(rows,function(a,b) return a.name<b.name end);return rows
  end
  return api
end
return M
