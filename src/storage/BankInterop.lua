-- Data-only bank interchange. Provider records survive as namespaced metadata;
-- no downloaded Lua chunks, bytecode or provider callbacks are executed.
local I={VERSION=1,MAX_BYTES=8*1024*1024}
local S=require('src.core.SaveSerializer')
local L=require('src.storage.LuaData')
local B=require('src.storage.PokemonBank')
local Games=require('src.core.GameVersion')
local methods={inspect=true,deposit=true,previewLegacy=true,importLegacy=true,export=true,formats=true}
function I.supports(name) return methods[name]==true end
local function hash(value) return love.data.encode('string','hex',love.data.hash('sha256',value)) end
local function clone(v) return S.decode(S.encode(v)) end
local function identifier(v) return type(v)=='string' and #v>0 and #v<=160 end
local function array(v,limit)
  if type(v)~='table' then return false end
  local n=0
  for k in pairs(v) do if type(k)~='number' or k%1~=0 or k<1 or k>limit then return false end;n=n+1 end
  for i=1,n do if v[i]==nil then return false end end
  return true
end
local function payload(row)
  local out={}
  for _,key in ipairs({'vaultMonId','species','current','identity','genetics','training','progress','evolution','moveMemory','heldItem','extensions'}) do out[key]=row[key] end
  return out
end
function I.preview(bytes,sourceVersion)
  if type(bytes)~='string' or #bytes>I.MAX_BYTES then return nil,'Invalid interchange size.' end
  local ok,package=pcall(S.decode,bytes)
  if not ok or type(package)~='table' or type(package.manifest)~='table' then return nil,'Expected a data-only Bank package.' end
  local inventory=L.inspect(package);if not inventory.serializable then return nil,inventory.reason end
  if package.manifest.kind=='retrorecomped.bank-copy' then
    local encoded,why=L.encode(package.record,B.MAX_BYTES)
    if package.manifest.version~=1 or not encoded or hash(encoded)~=package.manifest.digest or not B.decode(encoded) then return nil,why or 'Invalid Bank-copy checksum or schema.' end
    return {schema=1,provider='retrorecomped',sourceVersion=sourceVersion,digest=hash(bytes),package=package,entries={clone(package.record)},blocked={},lua=L.inspect(package.record),items={}}
  end
  if type(package.payload)~='table' then return nil,'Expected a Legacy Vault payload.' end
  local manifest,vault=package.manifest,package.payload
  if manifest.kind~='kanto-ascendant.legacy-bank-package' or manifest.packageVersion~=1
    or vault.kind~='kanto-ascendant.legacy-bank-vault' or vault.schemaVersion~=1 and vault.schemaVersion~=2
    or not identifier(vault.vaultId) or manifest.vaultId~=vault.vaultId or manifest.schemaVersion~=vault.schemaVersion
    or not array(vault.pokemon,4096) or type(manifest.entrySha256)~='table' then return nil,'Unsupported Legacy Bank schema.' end
  if manifest.containsRom~=false or manifest.absolutePaths~=false then return nil,'The package must declare no ROM data or absolute paths.' end
  if hash(S.encode(vault))~=manifest.payloadSha256 then return nil,'Legacy Vault checksum mismatch.' end
  local preview={schema=1,provider='kanto_ascendant',sourceVersion=sourceVersion,digest=hash(bytes),package=package,entries={},blocked={},lua=L.inspect(vault)}
  local seen={}
  for index,row in ipairs(vault.pokemon) do
    if type(row)~='table' or not identifier(row.vaultMonId) or seen[row.vaultMonId] or type(row.current)~='table' or type(row.current.payload)~='table'
      or row.origin~=nil and type(row.origin)~='table'
      or hash(S.encode(payload(row)))~=row.payloadSha256 or manifest.entrySha256[row.vaultMonId]~=row.payloadSha256 then return nil,'Invalid Legacy Pokémon record or checksum.' end
    seen[row.vaultMonId]=true
    local version=sourceVersion or (row.origin or {}).edition or (row.origin or {}).game
    local data,why
    if Games.VERSIONS[version] then data,why=B.data(version) else why='Choose an imported source game for this Legacy edition.' end
    if row.lease then why='This Legacy record is leased or has a pending transaction. Resolve it in KASC first.';data=nil end
    if not data then preview.blocked[#preview.blocked+1]={id=row.vaultMonId,reason=why}
    else
      local mon=clone(row.current.payload)
      mon.level=mon.level or row.current.level
      if (type(mon.species)~='string' and type(mon.species)~='number') or type(mon.level)~='number' or mon.level%1~=0 or mon.level<1 or mon.level>100
        or not array(mon.moves,4) then return nil,'Invalid Legacy Pokémon payload.' end
      for i,move in ipairs(mon.moves or {}) do if type(move)=='string' or type(move)=='number' then mon.moves[i]={id=move,pp=(data.moves[move] or {}).pp or 0} end end
      for _,move in ipairs(mon.moves) do if type(move)~='table' or type(move.id)~='string' and type(move.id)~='number' then return nil,'Invalid Legacy move payload.' end end
      local entry=B.makeEntry(mon,version,tostring((row.origin or {}).run or 'Legacy Vault'),'KASC Legacy Bank',data)
      entry.origin.recordId=hash('kanto_ascendant|'..vault.vaultId..'|'..row.vaultMonId)
      entry.extensions={schema=1,providers={kanto_ascendant={schema=vault.schemaVersion,vaultId=vault.vaultId,record=clone(row),packageDigest=manifest.payloadSha256}}}
      local encoded,err=L.encode(entry,B.MAX_BYTES)
      if not encoded or not B.decode(encoded) then preview.blocked[#preview.blocked+1]={id=row.vaultMonId,reason=err or 'The source record needs an explicit Pokémon adapter.'}
      else preview.entries[#preview.entries+1]=entry end
    end
  end
  if vault.items~=nil and type(vault.items)~='table' then return nil,'Invalid Legacy item inventory.' end
  local count=0
  for id,item in pairs(vault.items or {}) do
    count=count+1
    if count>4096 or not identifier(id) or type(item)~='table' or item.itemId~=id or type(item.quantity)~='number' or item.quantity%1~=0 or item.quantity<1
      or item.scope~='crossgen_mega' and item.scope~='kanto_only' or type(manifest.itemSha256)~='table' then return nil,'Invalid Legacy item record.' end
    local wanted=hash(S.encode({itemId=item.itemId,quantity=item.quantity,scope=item.scope,provenance=item.provenance}))
    if item.payloadSha256~=wanted or manifest.itemSha256[id]~=wanted then return nil,'Legacy item checksum mismatch.' end
  end
  preview.items=clone(vault.items or {});return preview
end
function I.commit(preview,confirmed)
  if confirmed~=true then return nil,'Explicit confirmation is required before importing Legacy copies.' end
  local permitted,why=require('src.storage.AccountStorage').check();if not permitted then return nil,why end
  local bytes,err=L.encode(preview and preview.package,I.MAX_BYTES);if not bytes then return nil,err end
  -- Recompute every entry from its verified source instead of trusting a
  -- caller-modified preview. A user-selected source edition is recorded.
  local checked,problem=I.preview(bytes,preview.sourceVersion);if not checked then return nil,problem end
  if #checked.blocked>0 then return nil,'Resolve blocked Legacy records before importing. Originals were preserved.' end
  local fs=require('src.core.SaveData').persistenceFs();fs.createDirectory('bank/interop')
  local path='bank/interop/'..checked.digest..'.lua'
  local prior=fs.read(path);if prior and prior~=bytes then return nil,'The existing interchange archive was preserved because its contents differ.' end
  local stored,reason=require('src.core.SaveSafety').atomicWrite(fs,path,bytes,{decode=require('src.core.SaveSafety').decodeAny})
  if not stored then return nil,reason end
  local ids={}
  for _,entry in ipairs(checked.entries) do local id,failure=B.keep(entry);if not id then return nil,failure end;ids[#ids+1]=id end
  return {schema=1,provider=checked.provider,entries=ids,itemsPreserved=true,archive=path,copyOnly=true}
end
function I.sync(store)
  local permitted,why=require('src.storage.AccountStorage').storeCheck(store);if not permitted then return nil,why end
  local fs=require('src.core.SaveData').persistenceFs();local directory='bank/interop';local pending={}
  local function valid(bytes,id)
    if type(id)~='string' or #id~=64 or not id:match('^[a-f0-9]+$') or type(bytes)~='string' or #bytes>I.MAX_BYTES or hash(bytes)~=id then return nil end
    return I.preview(bytes)
  end
  for _,name in ipairs(fs.getDirectoryItems(directory) or {}) do
    local id=name:match('^([a-f0-9]+)%.lua$')
    if id then
      local bytes=fs.read(directory..'/'..name)
      if not valid(bytes,id) then return nil,'Local Legacy archive needs recovery. Both copies were preserved.' end
      pending[id]=bytes
    end
  end
  local count=0
  for _,name in ipairs(store.list(directory) or {}) do
    local id=name:match('^([a-f0-9]+)%.lua$')
    if id then
      local path=directory..'/'..name;local bytes=store.read(path)
      if not valid(bytes,id) then return nil,'Remote Legacy archive failed its checksum or schema. Both copies were preserved.' end
      local existing=fs.read(path)
      if existing and existing~=bytes then return nil,'Legacy archive conflict. The existing copy was preserved.' end
      if not existing then
        fs.createDirectory(directory)
        local ok,err=require('src.core.SaveSafety').atomicWrite(fs,path,bytes,{decode=require('src.core.SaveSafety').decodeAny})
        if not ok then return nil,err end
      end
      pending[id]=nil;count=count+1
    end
  end
  for id,bytes in pairs(pending) do
    local ok,err=store.write(directory..'/'..id..'.lua',bytes);if not ok then return nil,err end
    count=count+1
  end
  return count
end
function I.facade(modId,version)
  local Policy=require('src.storage.AccountStorage');local account=Policy.scope()
  local function allowed()
    local ok,why=Policy.check();if not ok then return nil,why end
    if Policy.enabled and Policy.scope()~=account then return nil,'The Bank account changed. Open a new handle.' end
    return true
  end
  return {version=I.VERSION,
    formats=function() return {schema=1,formats={'retrorecomped.bank-copy/v1','kanto-ascendant.legacy-bank-package/v1'}} end,
    inspect=function(_,value) return L.inspect(value) end,
    previewLegacy=function(_,bytes,gameVersion) local p,why=I.preview(bytes,gameVersion);if p then p.sourceVersion=gameVersion end;return p,why end,
    importLegacy=function(_,preview,confirmed) local ok,why=allowed();if not ok then return nil,why end;return I.commit(preview,confirmed) end,
    export=function(_,id,confirmed)
      if confirmed~=true then return nil,'Explicit confirmation is required before exporting a Bank copy.' end
      local permitted,why=allowed();if not permitted then return nil,why end
      for _,entry in ipairs(B.list()) do if entry.id==id then
        entry.id=nil;local bytes=S.encode(entry)
        return {manifest={kind='retrorecomped.bank-copy',version=1,digest=hash(bytes)},record=entry}
      end end
      return nil,'Choose an existing Bank record.'
    end,
    deposit=function(_,game,mon,confirmed)
      if confirmed~=true then return nil,'Explicit confirmation is required before depositing a Bank copy.' end
      local permitted,problem=allowed();if not permitted then return nil,problem end
      local bytes,why=L.encode(mon,B.MAX_BYTES);if not bytes then return nil,why end
      if not game or not game.save or not Games.VERSIONS[game.save.version] or not game.data or not game.data.pokemon or not game.data.moves then return nil,'Choose an active save with imported game data first.' end
      local decoded=S.decode(bytes)
      if type(decoded)~='table' or not array(decoded.moves,4) then return nil,'Invalid Pokémon data.' end
      for _,move in ipairs(decoded.moves) do if type(move)~='table' or type(move.id)~='string' and type(move.id)~='number' then return nil,'Invalid Pokémon move data.' end end
      local entry=B.makeEntry(decoded,game.save.version,require('src.core.SaveData').activeSlot(game.save.version) or 'legacy','Mod '..modId,game.data,game.save)
      entry.extensions={schema=1,providers={[modId]={schema=1,version=version}}}
      return B.keep(entry)
    end,
  }
end
return I
