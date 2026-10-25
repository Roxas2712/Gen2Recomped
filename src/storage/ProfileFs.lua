-- Account-private progress shares installed ROMs/packages and the installation
-- identity. The first linked account keeps legacy paths without moving data.
local F={}
local S=require('src.core.SaveSerializer')
local cache=setmetatable({},{__mode='k'})
local function valid(id) return type(id)=='string' and #id<=20 and id:match('^[1-9][0-9]*$') end
local function legacy(base)
  local bytes=base.read('storage_account.lua');if not bytes then return nil end
  local ok,value=pcall(S.decode,bytes)
  if ok and type(value)=='table' and value.schema==1 and valid(value.accountId) then return value.accountId end
  return false
end
function F.prefix(base,id)
  local owner=legacy(base)
  if owner==false then return '' end -- surface corruption through the policy
  if valid(id) and (not owner or owner==id) then return '' end
  return 'profiles/'..(valid(id) and id or 'guest')..'/'
end
local function private(path)
  return path:match('^options%.lua') or path:match('^storage_account%.lua') or path:match('^save[%w_]*%.lua')
    or path:match('^cloud_sync') or path:match('^cloud_google%.lua') or path:match('^cloud_microsoft%.lua')
    or path:match('^saves[/]') or path=='saves' or path:match('^bank[/]') or path=='bank'
    or path:match('^states[/]') or path=='states' or path:match('^cloud_backups[/]') or path=='cloud_backups'
    or path:match('^modstorage[/]') or path=='modstorage'
    or path:match('^mod_storage[/]') or path=='mod_storage'
    or path:match('^exports[/]') or path=='exports'
end
function F.wrap(base,id)
  if base._profileBase then return base end
  local prefix=F.prefix(base,id);local byPrefix=cache[base] or {};cache[base]=byPrefix
  if byPrefix[prefix] then return byPrefix[prefix] end
  local fs={_profileBase=base,_accountPrefix=prefix}
  function fs.mapPath(path) return prefix~='' and private(path) and prefix..path or path end
  for _,method in ipairs({'read','getInfo','remove','getDirectoryItems','createDirectory','getRealDirectory'}) do
    if base[method] then fs[method]=function(path,...) return base[method](fs.mapPath(path),...) end end
  end
  function fs.write(path,bytes,...)
    local mapped=fs.mapPath(path);local parent=mapped:match('^(.*)/[^/]+$')
    if parent and base.createDirectory then base.createDirectory(parent) end
    return base.write(mapped,bytes,...)
  end
  if base.realPath then fs.realPath=function(path) return base.realPath(fs.mapPath(path)) end end
  setmetatable(fs,{__index=base});byPrefix[prefix]=fs;return fs
end
F.valid=valid
return F
