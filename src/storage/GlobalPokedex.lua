-- Account-wide union of observed/caught species; no ROM assets are uploaded.
local D={FILE='bank/pokedex.lua'}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local function disk() return Saves.persistenceFs() end
function D.decode(bytes)
  if type(bytes)~='string' or #bytes>4*1024*1024 then return nil end
  local ok,v=pcall(S.decode,bytes)
  if not ok or type(v)~='table' or v.schema~=1 or type(v.species)~='table' then return nil end
  local total=0
  for id,row in pairs(v.species) do
    total=total+1
    if total>4096 or type(id)~='number' or id<1 or id>4096 or id%1~=0 or type(row)~='table'
      or type(row.sources)~='table' or row.owned~=nil and type(row.owned)~='boolean' then return nil end
    local count=0
    for key,source in pairs(row.sources) do
      count=count+1
      if count>512 or type(key)~='string' or #key>200 or type(source)~='table'
        or not Versions.VERSIONS[source.version] or type(source.slot)~='string' or #source.slot>80 then return nil end
    end
  end
  return v
end
function D.load()
  local bytes=disk().read(D.FILE)
  if not bytes then return {schema=1,species={}} end
  return D.decode(bytes),'Global Pokédex needs recovery. Existing records are preserved.'
end
function D.merge(a,b)
  for id,other in pairs(b.species) do
    local row=a.species[id] or {sources={}};a.species[id]=row
    row.owned=row.owned or other.owned or false;row.name=row.name or other.name
    for key,source in pairs(other.sources) do row.sources[key]=source end
  end
  return a
end
function D.collect(ready,entries)
  local dex,why=D.load();if not dex then return nil,why end
  local B=require('src.storage.PokemonBank')
  local function add(id,name,version,slot,owned)
    id=tonumber(id);if not id or id%1~=0 or id<1 or id>4096 then return end
    local row=dex.species[id] or {sources={}};dex.species[id]=row
    row.name=row.name or name;row.owned=row.owned or owned or false
    row.sources[version..':'..slot]={version=version,slot=slot}
  end
  for _,entry in ipairs(entries or B.list()) do
    add(entry.canonical.dex,tostring(entry.mon.species),entry.source.version,tostring(entry.source.slot or 'Bank'),true)
  end
  for _,version in ipairs(Versions.ORDER) do
    if ready[version] then
      local data=B.data(version)
      if data then
        for _,slot in ipairs(Saves.listSlots(version)) do
          local save=Saves.peekSlot and Saves.peekSlot(version,slot.id) or B.readSave(version,slot.id)
          if save then
            for _,kind in ipairs({'seen','owned'}) do
              for species,present in pairs((save.pokedex or {})[kind] or {}) do
                local def=data.pokemon[species] or {}
                if present then add(def.dex or def.nationalDex or tonumber(species),def.name or tostring(species),version,slot.id,kind=='owned') end
              end
            end
            for _,row in ipairs(B.scan(save,version)) do
              local def=data.pokemon[row.mon.species] or {}
              add(def.dex or def.nationalDex,def.name or tostring(row.mon.species),version,slot.id,true)
            end
          end
        end
      end
    end
  end
  if not D.decode(S.encode(dex)) then return nil,'Global Pokédex exceeds its storage limits.' end
  disk().createDirectory('bank')
  local ok,err=Safety.atomicWrite(disk(),D.FILE,S.encode(dex),{decode=D.decode})
  return ok and dex or nil,err
end
function D.rows(dex)
  local rows={};local owned=0
  for id,row in pairs(dex.species) do
    rows[#rows+1]={id=id,name=row.name or ('#'..id),owned=row.owned,sources=row.sources}
    if row.owned then owned=owned+1 end
  end
  table.sort(rows,function(a,b) return a.id<b.id end);return rows,owned
end
function D.sync(store)
  local before=disk().read(D.FILE);local dex,why=D.load();if not dex then return nil,why end
  local bytes=store.read(D.FILE);local remote
  if bytes then remote=D.decode(bytes) else remote={schema=1,species={}} end
  if not remote then return nil,'Remote Pokédex is unreadable. Both copies are preserved.' end
  if disk().read(D.FILE)~=before then return nil,'Pokédex changed during sync. Please retry.' end
  local merged=S.encode(D.merge(dex,remote));if not D.decode(merged) then return nil,'Merged Pokédex exceeds storage limits.' end
  local ok,err=store.write(D.FILE,merged);if not ok then return nil,err end
  if disk().read(D.FILE)~=before then return nil,'Pokédex changed during sync. Please retry.' end
  disk().createDirectory('bank');return Safety.atomicWrite(disk(),D.FILE,merged,{decode=D.decode})
end
return D
