-- Preserve an unbound legacy walk when introducing separate guest profiles.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={MARKER='walker_legacy_migration.lua'}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local function names(file)return{file,file..'.tmp',file..'.bak'}end
local function hash(bytes)return require('src.import.CloudSync').hash(bytes)end
local function marker(base)
 local raw=base.read(M.MARKER)
 if not raw then return nil end
 local ok,value=pcall(S.decode,raw)
 if ok and type(value)=='table'and value.schema==1 and type(value.paths)=='table'then return value end
 return false
end
function M.read(fs,path)
 local bytes=fs.read(path)
 if not bytes or fs._accountPrefix~=''then return bytes end
 local record=marker(fs._profileBase)
 if record==false then return nil,'Pokéwalker storage needs recovery. Existing files were preserved.'end
 if record and record.paths[path]==hash(bytes)then return nil end
 return bytes
end
function M.migrateGuest(fs,file)
 if not fs then return true end
 local base=fs._profileBase
 if fs._accountPrefix~='profiles/guest/'or not base or base.read('storage_account.lua')then return true end
 for _,path in ipairs(names(file))do if fs.getInfo(path)then return true end end
 local record=marker(base)
 if record==false then return nil,'Pokéwalker storage needs recovery. Existing files were preserved.'end
 if record then return true end
 local originals,selected={},nil
 for _,path in ipairs(names(file))do
  local raw=base.read(path)
  if raw then
   originals[path]=raw
   local ok,value=pcall(S.decode,raw)
   if not selected and ok and type(value)=='table'and value.format==1 then selected=raw end
  end
 end
 if next(originals)==nil then return true end
 if not selected then return nil,'Pokéwalker storage needs recovery. Existing files were preserved.'end
 for path,bytes in pairs(originals)do
  local ok,why=Safety.atomicWrite(fs,'walker/legacy-unbound/'..path,bytes)
  if not ok then return nil,why end
 end
 local ok,why=Safety.atomicWrite(fs,file,selected,{decode=Safety.decodeAny})
 if not ok then return nil,why end
 local record={schema=1,paths={}}
 for path,bytes in pairs(originals)do record.paths[path]=hash(bytes)end
 ok,why=Safety.atomicWrite(base,M.MARKER,S.encode(record),{decode=Safety.decodeAny})
 if not ok then return nil,why end
 -- The verified private recovery copies exist before any legacy path moves.
 -- The marker also hides residual originals if a device dies during removal.
 for path in pairs(originals)do if base.remove then base.remove(path)end end
 return true
end
return M
