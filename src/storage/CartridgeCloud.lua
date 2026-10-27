-- Account-private designs and content-addressed PNG chunks. No ROM/cache data.
local C={PATH='profiles/cartridges/active.lua',STATE='cloud_sync_cartridges.lua',PART=1024*1024,MAX=8*1024*1024}
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local Safety=require('src.core.SaveSafety')
local Designer=require('src.import.CartDesigner')
local Versions=require('src.core.GameVersion')
local function hash(b) return love.data.encode('string','hex',love.data.hash('sha256',b)) end
local function digest(v) return type(v)=='string' and #v==64 and v:match('^[a-f0-9]+$') end
local function decode(bytes)
  if type(bytes)~='string' or #bytes>100000 then return nil end
  local ok,v=pcall(S.decode,bytes)
  if not ok or type(v)~='table' or v.schema~=1 or type(v.designs)~='table' or type(v.logo)~='boolean' then return nil end
  local count=0
  for version,row in pairs(v.designs) do
    count=count+1
    if count>100 or not Versions.VERSIONS[version] or type(row)~='table' or type(row.style)~='table' or row.style.art~=nil
      or S.encode(Designer.normalize(row.style))~=S.encode(row.style) then return nil end
    local a=row.image
    if a and (type(a)~='table' or not digest(a.id) or type(a.bytes)~='number' or a.bytes<1 or a.bytes>C.MAX
      or a.bytes%1~=0 or a.parts~=math.ceil(a.bytes/C.PART)) then return nil end
  end
  return v
end
C.decode=decode
local function png(bytes)
  return type(bytes)=='string' and #bytes<=C.MAX and bytes:sub(1,8)=='\137PNG\13\10\26\10'
    and require('src.import.ImageBounds').allowed(bytes,2048)
end
local function assetPath(id,i) return 'profiles/cartridges/assets/'..id..'_'..i..'.lua' end
function C.capture(options)
  local doc={schema=1,logo=options.launcherLogoCards~=false,designs={}};local images={}
  for version,value in pairs(type(options.launcherCartDesigns)=='table' and options.launcherCartDesigns or {}) do
    if Versions.VERSIONS[version] then
      local style=Designer.normalize(value);local row={style=style};doc.designs[version]=row
      if style.art then
        local bytes=love.filesystem.read(style.art)
        if not png(bytes) then return nil,'A local cartridge image is missing or invalid. Your design was preserved.' end
        local id=hash(bytes);images[id]=bytes;row.image={id=id,bytes=#bytes,parts=math.ceil(#bytes/C.PART)};style.art=nil
      end
    end
  end
  return doc,images
end
local function publish(store,doc,images)
  for id,bytes in pairs(images) do
    for i=1,math.ceil(#bytes/C.PART) do
      local payload=S.encode({schema=1,id=id,part=i,data=love.data.encode('string','base64',bytes:sub((i-1)*C.PART+1,i*C.PART))})
      local path=assetPath(id,i);local prior=store.read(path)
      if prior and prior~=payload then return nil,'Cloud artwork conflict. Neither copy was overwritten.' end
      if not prior then local ok,why=store.write(path,payload);if not ok then return nil,why end end
    end
  end
  return store.write(C.PATH,S.encode(doc))
end
local function restore(store,doc,beforeHash)
  local designs={}
  for version,row in pairs(doc.designs) do
    local style=Designer.normalize(row.style);designs[version]=style
    if row.image then
      local a=row.image;local chunks={}
      for i=1,a.parts do
        local raw=store.read(assetPath(a.id,i))
        if type(raw)~='string' or #raw>C.PART*1.5 then return nil,'Cloud artwork is incomplete. Local designs are preserved.' end
        local ok,part=pcall(S.decode,raw)
        if not ok or type(part)~='table' or part.id~=a.id or part.part~=i or type(part.data)~='string' then return nil,'Invalid cloud artwork chunk.' end
        local good,bytes=pcall(love.data.decode,'string','base64',part.data)
        if not good or #bytes>C.PART then return nil,'Invalid cloud artwork bytes.' end
        chunks[i]=bytes
      end
      local bytes=table.concat(chunks)
      if #bytes~=a.bytes or hash(bytes)~=a.id or not png(bytes) then return nil,'Cloud artwork fingerprint mismatch. Local designs are preserved.' end
      style.art='launcher/cart_art/cloud_'..a.id..'.png'
      local prior=love.filesystem.read(style.art)
      if prior and prior~=bytes then return nil,'Local artwork conflict. Existing image preserved.' end
      if not prior then
        love.filesystem.createDirectory('launcher/cart_art')
        local ok,why=Safety.atomicWrite(love.filesystem,style.art,bytes);if not ok then return nil,why end
      end
    end
  end
  local options=Saves.loadOptions();local current=C.capture(options)
  if not current or hash(S.encode(current))~=beforeHash then return nil,'Cartridges changed during sync. Retry; both versions are preserved.' end
  local disk=Saves.persistenceFs()
  local ok,why=Safety.atomicWrite(disk,'cloud_sync_cartridges_backup.lua',S.encode({designs=options.launcherCartDesigns or {},logo=options.launcherLogoCards}),{decode=Safety.decodeAny})
  if not ok then return nil,why end
  options.launcherCartDesigns=designs;options.launcherLogoCards=doc.logo
  if not Saves.saveOptions(options) then return nil,'Could not save the cloud cartridge preferences.' end
  return true
end
function C.sync(store,choice)
  local allowed,why=require('src.storage.AccountStorage').storeCheck(store);if not allowed then return nil,why end
  local localDoc,images=C.capture(Saves.loadOptions());if not localDoc then return nil,images end
  local localHash=hash(S.encode(localDoc));local disk=Saves.persistenceFs();local state={schema=1,bases={}}
  local old=disk.read(C.STATE)
  if old then local ok,v=pcall(S.decode,old);if not ok or type(v)~='table' or type(v.bases)~='table' then return nil,'Cartridge sync history needs recovery.' end;state=v end
  local scope=hash(store.profileScope or store.kind or 'default');local base=state.bases[scope]
  local raw=store.read(C.PATH);local remote=raw and decode(raw)
  if raw and not remote then return nil,'Cloud cartridge preferences are invalid. Local designs are preserved.' end
  if choice=='download' or choice=='cloud' then
    if not remote then return 'absent' end
    choice='cloud'
  end
  local remoteHash=remote and hash(S.encode(remote));local finalHash=localHash;local result='current'
  if remoteHash~=localHash then
    if choice=='local' or choice~='cloud' and (not remote or base and remoteHash==base) then
      local ok,err=publish(store,localDoc,images);if not ok then return nil,err end;result='uploaded'
    elseif choice=='cloud' or base==localHash or not base and next(localDoc.designs)==nil then
      local ok,err=restore(store,remote,localHash);if not ok then return nil,err end
      finalHash=remoteHash;result='restored'
    else return nil,'Cartridges changed on both devices. Choose Upload or Restore in Cloud settings; neither design was overwritten.' end
  end
  state.bases[scope]=finalHash
  local ok,err=Safety.atomicWrite(disk,C.STATE,S.encode(state),{decode=Safety.decodeAny});if not ok then return nil,err end
  return result
end
return C
