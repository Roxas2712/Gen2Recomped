-- Windows preview storage selection. Discovery is read-only; no migration.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local P={BOOTSTRAP='RetroRecomped-Windows-Demo',FILE='windows-demo-profile.json'}
local known={Gen2Recomp=true,RetroRecomped=true,RetroRecompedRS=true,['pokemon-love2d']=true,['Gen2Recomp-Love12Preview']=true}
function P.valid(identity)
 if type(identity)~='string'or #identity>160 then return false end
 local name=identity:match('^LOVE/(.+)$')or identity
 if not name:match('^[%w_.%-]+$')or name=='.'or name=='..'or name==P.BOOTSTRAP then return false end
 if name:lower():match('%-qa[%-%d]')then return false end
 return known[name]or name:match('^RetroRecomped[%w_.%-]*$')~=nil or name:match('^Gen2Recomp%-NativePreview%-%d+%-%d+$')~=nil
end
function P.scan(fs,base)
 base=base or fs.getAppdataDirectory()
 if type(base)~='string'or not fs.mountFullPath then return nil,'Die Profilordner konnten nicht sicher gelesen werden.'end
 local mount='__retro_windows_profiles'
 local ok,mounted=pcall(fs.mountFullPath,base,mount,'read',true)
 if not ok or not mounted then return nil,'Die Profilordner konnten nicht sicher gelesen werden.'end
 local rows={}
 local read,problem=pcall(function()
  local function inspect(identity)
   if not P.valid(identity)then return end
   local root=mount..'/'..identity..'/'
   local function exists(path)return fs.getInfo(root..path)~=nil end
   local progress=exists('saves')or exists('save.lua')or exists('bank')or exists('profiles')
   local imports=exists('rom-cache.complete')or exists('data/generated')or exists('assets/generated')
   for _,edition in ipairs{'blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald','platinum','heartgold','soulsilver','black','white','pinballrs','pokemonxy'}do
    imports=imports or exists(edition..'/rom-cache.complete')or exists(edition..'/data/generated')
    progress=progress or exists('save_'..edition..'.lua')
   end
   if progress or imports or exists('options.lua')or exists('storage_account.lua')then
    rows[#rows+1]={identity=identity,path=base..'/'..identity,progress=not not progress,imports=not not imports}
   end
  end
  for _,name in ipairs(fs.getDirectoryItems(mount))do
   if name=='LOVE'then for _,child in ipairs(fs.getDirectoryItems(mount..'/LOVE'))do inspect('LOVE/'..child)end
   else inspect(name)end
  end
 end)
 local released=fs.unmountFullPath or fs.unmount
 if released then pcall(released,base)end
 if not read then return nil,'Die Profilordner konnten nicht sicher gelesen werden.'end
 table.sort(rows,function(a,b)return a.identity<b.identity end)
 return rows
end
function P.choose(rows,saved)
 if saved and P.valid(saved.identity)then
  for _,row in ipairs(rows)do if row.identity==saved.identity then return row end end
 end
 if #rows==1 then return rows[1]end
 if #rows==0 then return{identity='Gen2Recomp',new=true}end
end
function P.readChoice(fs)
 local bytes=fs.read(P.FILE)
 if type(bytes)~='string'or #bytes>4096 then return end
 local ok,value=pcall(require('src.link.Json').decode,bytes)
 if ok and type(value)=='table'and value.schema==1 and P.valid(value.identity)then return value end
end
function P.remember(fs,row)
 if not P.valid(row.identity)then return nil,'Ungültiges Profil.'end
 local old=fs.read(P.FILE)
 if old and not P.readChoice(fs)then return nil,'Die bisherige Profilauswahl wurde zur Wiederherstellung erhalten.'end
 local bytes=require('src.link.Json').encode({schema=1,identity=row.identity})
 local ok,why=fs.write(P.FILE..'.tmp',bytes);if not ok then return nil,why end
 if fs.read(P.FILE..'.tmp')~=bytes then return nil,'Die Profilauswahl konnte nicht geprüft werden.'end
 if old then local saved,err=fs.write(P.FILE..'.bak',old);if not saved then return nil,err end end
 ok,why=fs.write(P.FILE,bytes)
 if ok and fs.read(P.FILE)==bytes then fs.remove(P.FILE..'.tmp');return true end
 return nil,why or 'Die Profilauswahl konnte nicht gespeichert werden.'
end
return P
