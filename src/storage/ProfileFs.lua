-- Account-private progress shares installed ROMs/packages and the installation
-- identity. The first linked account keeps legacy paths without moving data.
local F={}
local S=require('src.core.SaveSerializer')
local cache=setmetatable({},{__mode='k'})
local function valid(id) return type(id)=='string' and #id<=20 and id:match('^[1-9][0-9]*$') end
local function ownerAt(base,path)
  local bytes=base.read(path..'storage_account.lua')
  if not bytes then
    if base.getInfo and base.getInfo(path..'storage_account.lua')then return false end
    return nil
  end
  local ok,value=pcall(S.decode,bytes)
  if ok and type(value)=='table' and value.schema==1 and valid(value.accountId) then return value.accountId end
  return false
end
local function legacy(base)return ownerAt(base,'')end
local function guestPath(n)return n==1 and'profiles/guest/'or('profiles/guest-'..n..'/')end
function F.guestPrefix(base)
  for n=1,256 do local path=guestPath(n);if ownerAt(base,path)==nil then return path end end
  return nil,'No free local guest profile is available.'
end
function F.prefix(base,id)
  local owner=legacy(base)
  if not valid(id) then return assert(F.guestPrefix(base)) end
  if owner==id then return '' end
  local prefix='profiles/'..id..'/'
  -- An existing named profile keeps its own routing even if the legacy
  -- binding needs repair. Invalid named bindings are surfaced by the policy.
  if base.read(prefix..'storage_account.lua')~=nil then return prefix end
  for n=1,256 do
    local path=guestPath(n);local guestOwner=ownerAt(base,path)
    if guestOwner==id then return path end
    -- Only the first unowned guest profile can be adopted. All earlier
    -- claimed profiles remain private after sign-out, without moving saves.
    if guestOwner==nil then break end
  end
  if owner==false or not owner then return '' end
  return prefix
end
local function private(path)
  if path:match('^cloud_outbox%.lua')then return true end
  return path:match('^options%.lua') or path:match('^storage_account%.lua') or path:match('^save[%w_]*%.lua')
    or path:match('^cloud_sync') or path:match('^cloud_google%.lua') or path:match('^cloud_microsoft%.lua')
    or path:match('^saves[/]') or path=='saves' or path:match('^bank[/]') or path=='bank'
    or path:match('^states[/]') or path=='states' or path:match('^cloud_backups[/]') or path=='cloud_backups'
    or path:match('^modstorage[/]') or path=='modstorage'
    or path:match('^mod_storage[/]') or path=='mod_storage'
    or path:match('^exports[/]') or path=='exports'
    or path:match('^pokewalker%.lua') or path:match('^pokewalker_backups[/]') or path=='pokewalker_backups'
    or path:match('^walker[/]') or path=='walker'
    or path:match('^minigames[/]') or path=='minigames'
end
function F.wrap(base,id)
  if base._profileBase then return base end
  local prefix=F.prefix(base,id);local byPrefix=cache[base] or {};cache[base]=byPrefix
  if byPrefix[prefix] then return byPrefix[prefix] end
  local fs={_profileBase=base,_accountPrefix=prefix}
  function fs.mapPath(path) return prefix~='' and private(path) and prefix..path or path end
  for _,method in ipairs({'read','getInfo','remove','getDirectoryItems','createDirectory','getRealDirectory','newFile'}) do
    if base[method] then fs[method]=function(path,...) return base[method](fs.mapPath(path),...) end end
  end
  function fs.write(path,bytes,...)
    local mapped=fs.mapPath(path);local parent=mapped:match('^(.*)/[^/]+$')
    if parent and base.createDirectory then base.createDirectory(parent) end
    return base.write(mapped,bytes,...)
  end
  if base.realPath then fs.realPath=function(path) return base.realPath(fs.mapPath(path)) end end
  if not fs.realPath and love and base==love.filesystem and base.getSaveDirectory then
    fs.realPath=function(path)return base.getSaveDirectory()..'/'..fs.mapPath(path)end
  end
  if base.rename then fs.rename=function(from,to)return base.rename(fs.mapPath(from),fs.mapPath(to))end end
  setmetatable(fs,{__index=base});byPrefix[prefix]=fs;return fs
end
F.valid=valid
return F
