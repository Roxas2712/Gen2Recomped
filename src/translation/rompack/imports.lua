-- Native optional imports with SHA-1 profile verification and legacy migration.
-- Uses the launcher's atomic import store; never changes CacheFs.prefix.
return function(mod,own)
  local Imports=require('src.mods.ModImports')
  local manifest=assert(mod.languageManifest)
  local native=mod.imports
  local specs,identities={},{}
  for _,entry in ipairs(Imports.of(manifest)) do specs[entry.id]=entry end
  for _,row in ipairs(own('rom_requirements.lua')) do
    identities[row.game..'_en']=row.base.sha1
    for _,entry in ipairs(own('catalog.lua')) do
      if entry.game==row.game then
        for _,source in ipairs(row.sources) do
          if entry.language==source.language then identities[entry.sourceId or entry.id]=source.sha1 end
        end
      end
    end
  end
  local function hash(kind,bytes)
    return love.data.encode('string','hex',love.data.hash(kind,bytes))
  end
  local validated={}
  local function readNative(id,offset,length)
    local chunks={}
    for at=offset,offset+length-1,4*1024*1024 do
      local bytes,why=native:read(id,at,math.min(4*1024*1024,offset+length-at))
      if not bytes then return nil,why end
      chunks[#chunks+1]=bytes
    end
    return table.concat(chunks)
  end
  local api={}
  function api:info(id)
    local spec=specs[id]
    if not spec or not identities[id] then return nil end
    local info=native:info(id)
    local key='language-inputs/'..id..'.bin'
    local old=not info and mod.cache:info(key)
    if not info and not old then validated[id]=nil;return nil end
    local stat=info or old
    local memo=validated[id]
    if memo and memo.modtime==stat.modtime and memo.size==stat.size and memo.legacy==(old~=nil) then return memo end
    local bytes=info and readNative(id,0,info.size) or mod.cache:read(key)
    if type(bytes)~='string' or #bytes~=spec.size or hash('sha1',bytes)~=identities[id] then return nil end
    local valid=Imports.check(spec,bytes)
    if not valid then return nil end
    -- Existing installations retain their sources; the shared launcher bank
    -- now also recognizes bytes supplied through the in-game picker.
    if old then
      local ok,why=Imports.install(manifest,spec,bytes)
      if not ok then mod.log:warn('Language input migration: %s',tostring(why)) end
    end
    memo={id=id,size=#bytes,md5=hash('md5',bytes),sha1=identities[id],modtime=stat.modtime,legacy=old~=nil}
    validated[id]=memo
    return memo
  end
  function api:read(id,offset,length)
    local info=self:info(id)
    if not info then return nil,'Language ROM is missing or invalid' end
    offset=offset or 0;length=length or info.size
    if type(offset)~='number' or type(length)~='number' or offset%1~=0 or length%1~=0
      or offset<0 or length<0 or offset+length>info.size then return nil,'Invalid ROM slice' end
    local data=readNative(id,offset,length)
    if data then return data end
    local bytes=mod.cache:read('language-inputs/'..id..'.bin')
    return bytes and bytes:sub(offset+1,offset+length)
  end
  function api:import(bytes,game)
    if type(bytes)~='string' or #bytes>32*1024*1024 then return nil,'Invalid language ROM size' end
    local allowed={[game..'_en']=true}
    for _,entry in ipairs(own('catalog.lua')) do
      if entry.game==game then allowed[entry.sourceId or entry.id]=true end
    end
    local sha=hash('sha1',bytes)
    for id,spec in pairs(specs) do
      if allowed[id] and identities[id]==sha and #bytes==spec.size then
        local ok,why=Imports.install(manifest,spec,bytes)
        if not ok then return nil,why end
        validated[id]=nil
        if not self:info(id) then return nil,'Import verification failed' end
        return id
      end
    end
    return nil,'This ROM does not match a supported language profile for '..tostring(game)
  end
  return api
end
