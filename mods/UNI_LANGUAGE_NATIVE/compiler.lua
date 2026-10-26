-- Persistent, disposable compilation cache in mod.cache. The commit index is
-- written last; missing/corrupt payloads cause a complete rebuild before apply.
return function(mod,key,compile,options)
 local W=require('src.core.SaveSerializer')
 local B=assert(loadstring(assert(mod:read('cache_codec.lua'))))()
 local function hash(bytes) return love.data.encode('string','hex',love.data.hash('string','sha256',bytes)) end
 local cache=mod.cache
 local lazy=options and options.lazyAssets
 local root='compiled/'..key..'/'
 local function assetTable(files,packed)
  setmetatable(files,{__index=function(t,path)
   local bytes=packed[path]
   if bytes then
    local raw=love.data.decompress('string','zlib',bytes)
    rawset(t,path,raw);packed[path]=nil
    return raw
   end
  end})
  return function()
   -- Public inspection still receives the complete ordinary string table.
   for path in pairs(packed)do local _=files[path] end
   return files
  end
 end
 local function decode(bytes) return assert(W.decode(bytes,{maxBytes=16*1024*1024,maxNodes=500000,maxDepth=40})) end
 local function load()
  if not cache then return end
  local index=cache:read(root..'index.lua')
  if not index then return end
  local ok,value=pcall(function()
   local index=decode(index)
   assert(index.format==2 and index.key==key and type(index.rows)=='table')
   local files,packed,operations,report={},{},{},nil
   for _,row in ipairs(index.rows) do
    assert(type(row.path)=='string' and row.path:match('^[%w_./-]+$') and not row.path:find('..',1,true))
    local data=assert(cache:read(root..row.path))
    assert(#data==row.size and hash(data)==row.hash,'incomplete language cache')
    if row.kind=='asset' then files[row.name]=data
    elseif row.kind=='asset-zlib' then
     -- Validate every expanded payload before applying any content, then
     -- retain only compressed bytes for graphics that are not yet needed.
     assert(type(row.rawSize)=='number' and row.rawSize>=0 and row.rawSize<=64*1024*1024)
     local raw=love.data.decompress('string','zlib',data)
     assert(#raw==row.rawSize and hash(raw)==row.rawHash,'invalid compressed language asset')
     if lazy then packed[row.name]=data else files[row.name]=raw end
    elseif row.kind=='report' then report=B.decode(data)
    elseif row.kind=='operations' then for _,op in ipairs(B.decode(data)) do operations[#operations+1]=op end
    else error('unknown cache payload') end
   end
   assert(type(report)=='table' and #operations>0)
   return {files=files,operations=operations,report=report,materialize=assetTable(files,packed)}
  end)
  if ok then return value end
  mod.log:warn('Language cache invalid; rebuilding: %s',tostring(value))
 end
 local compiled=load()
 local hit=compiled~=nil
 if not compiled then
  compiled=compile()
  -- An override replaces the entire previous value for this registry/key.
  -- Keep only that override and subsequent patches, at its original first-
  -- touch position. Other keys and patch-only chains retain their order.
  local slots,chains={},{}
  for _,op in ipairs(compiled.operations)do
   assert(op.method=='override' or op.method=='patch','Invalid compilation operation')
   chains[op.registry]=chains[op.registry] or {}
   local chain=chains[op.registry][op.key]
   if not chain then chain={};chains[op.registry][op.key]=chain end
   if op.method=='override' and #chain>0 then
    local first=chain[1]
    for _,i in ipairs(chain)do slots[i]=false end
    slots[first]=op;chains[op.registry][op.key]={first}
   else
    slots[#slots+1]=op;chain[#chain+1]=#slots
   end
  end
  compiled.operations={}
  for _,op in ipairs(slots)do if op then compiled.operations[#compiled.operations+1]=op end end
  local packed,assetRows={},{}
  local names={};for path in pairs(compiled.files)do names[#names+1]=path end;table.sort(names)
  for _,path in ipairs(names)do
   local raw=compiled.files[path]
   local row={name=path,bytes=raw,kind='asset'}
   -- PNGs are already compressed; Lua manifests remain immediately readable.
   if lazy and #raw>=4096 and path:match('%.(.-)$')~='lua' and not path:match('%.png$')then
    local bytes=love.data.compress('string','zlib',raw,1)
    if #bytes+64<#raw then
     row.bytes=bytes;row.kind='asset-zlib';row.rawSize=#raw;row.rawHash=hash(raw)
     packed[path]=bytes;compiled.files[path]=nil
    end
   end
   assetRows[#assetRows+1]=row
  end
  compiled.materialize=assetTable(compiled.files,packed)
  if cache then
   local ok,err=pcall(function()
    cache:delete(root..'index.lua')
    local index={format=2,key=key,rows={}}
    local function write(path,bytes,kind,name,rawSize,rawHash)
     assert(cache:write(root..path,bytes))
     index.rows[#index.rows+1]={path=path,size=#bytes,hash=hash(bytes),kind=kind,name=name,rawSize=rawSize,rawHash=rawHash}
    end
    for i,row in ipairs(assetRows)do write('assets/'..i..'.bin',row.bytes,row.kind,row.name,row.rawSize,row.rawHash)end
    for i=1,#compiled.operations,500 do
     local batch={};for j=i,math.min(i+499,#compiled.operations) do batch[#batch+1]=compiled.operations[j] end
     write('operations/'..i..'.bin',B.encode(batch),'operations')
    end
    write('report.bin',B.encode(compiled.report),'report')
    assert(cache:write(root..'index.lua',W.encode(index)))
   end)
   if not ok then mod.log:warn('Language cache could not be saved: %s',tostring(err)) end
  end
 end
 -- All cached payloads are validated before any operation reaches the loader.
 for _,op in ipairs(compiled.operations) do
  local registry=assert(mod.content[op.registry])
  assert(op.method=='override' or op.method=='patch')
  registry[op.method](registry,op.key,op.value)
 end
 compiled.report.cacheHit=hit
 return compiled.files,compiled.report,compiled.materialize
end
