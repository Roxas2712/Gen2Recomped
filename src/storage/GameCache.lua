-- Account-private imported data. Immutable verified blocks and manifests;
-- the account head is published only after every block has reached storage.
local C={BLOCK=1024*1024,MAX_FILE=32*1024*1024,MAX_TOTAL=1024*1024*1024,MAX_FILES=50000,STATE='cloud_sync_games.lua',
 REGISTRY='launcher/game_cache_registry.lua'}
local S=require('src.core.SaveSerializer')
local Versions=require('src.core.GameVersion')
local Safety=require('src.core.SaveSafety')
local function hash(b) return love.data.encode('string','hex',love.data.hash('sha256',b)) end
local function digest(v) return type(v)=='string' and #v==64 and v:match('^[a-f0-9]+$') end
local function integer(v,max) return type(v)=='number' and v%1==0 and v>=0 and v<=max end
local function disk() return require('src.import.CacheFs').dataFs() end
local function account() return require('src.cloud.RetroCloud').accountId() end
local function tick(note,progress) if progress then progress(note) end;require('src.cloud.Task').yield() end
local function parse(bytes,max)
 if type(bytes)~='string' or #bytes>(max or 8*1024*1024) then return end
 return S.decode(bytes)
end
function C.path(path)
 if type(path)~='string' or #path>240 or path:find('[^%w_./%-]') or path:find('..',1,true) or path:find('//',1,true) then return false end
 if path:match('^data/generated/[%w_/%-]+%.lua$') then return true end
 local ext=path:match('^assets/generated/[%w_./%-]+%.([%w]+)$')
 return ext and ({png=true,wav=true,ogg=true,bin=true,dat=true,json=true,txt=true,lz=true,narc=true})[ext] or false
end
function C.validateFile(path,bytes)
 if not C.path(path) or type(bytes)~='string' or #bytes>C.MAX_FILE then return nil,'Invalid imported data file.' end
 if path:sub(1,15)=='data/generated/' then
  local value,why=require('src.import.DataLiteral').decode(bytes,{bytes=C.MAX_FILE,depth=96,nodes=3000000,string=8*1024*1024,entries=1000000,chunked=true})
  if not value then return nil,'Generated data contains unsupported executable content: '..tostring(why) end
 end
 return true
end
function C.decode(bytes)
 local m=parse(bytes)
 if type(m)~='table' or m.schema~=1 or not Versions.VERSIONS[m.version] or type(m.marker)~='string' or #m.marker>65536
  or m.rom~=Versions.info(m.version).sha1 or not integer(m.total,C.MAX_TOTAL) or m.total==0 or type(m.files)~='table'
  or #m.files<1 or #m.files>C.MAX_FILES or type(m.blocks)~='table' or #m.blocks~=math.ceil(m.total/C.BLOCK) then return nil,'Invalid private game manifest.' end
 local pos,seen=0,{}
 for _,f in ipairs(m.files) do
  if type(f)~='table' or not C.path(f.path) or seen[f.path] or not digest(f.sha256) or not integer(f.size,C.MAX_FILE) or f.offset~=pos then return nil,'Invalid private game file list.' end
  seen[f.path]=true;pos=pos+f.size
 end
 if pos~=m.total then return nil,'Private game size mismatch.' end
 for i,b in ipairs(m.blocks) do
  if type(b)~='table' or not digest(b.id) or b.size~=math.min(C.BLOCK,m.total-(i-1)*C.BLOCK) then return nil,'Invalid private game block list.' end
 end
 return m
end
local function registry()
 local raw=disk().read(C.REGISTRY);local r=raw and parse(raw,128*1024)
 if raw and (not r or r.schema~=1 or type(r.accounts)~='table') then return nil,'Private game registry needs recovery.' end
 return r or {schema=1,accounts={}}
end
function C.refresh()
 C.active={};C.account=account()
 if type(C.account)~='string' or not C.account:match('^[1-9][0-9]*$') then return end
 local r=registry();local rows=r and r.accounts[C.account] or {}
 for v,id in pairs(rows or {}) do
  if Versions.VERSIONS[v] and digest(id) then
   local root='launcher/private_games/'..C.account..'/'..id..'/'
   local bytes=disk().read(root..'manifest.lua');local m=bytes and hash(bytes)==id and C.decode(bytes)
   if m and m.version==v and disk().read(root..'rom-cache.complete')==m.marker then C.active[v]={root=root,id=id,marker=m.marker} end
  end
 end
end
function C.prefix(version) return C.account~=nil and C.account==account() and C.active and C.active[version] and C.active[version].root end
function C.identity(version) return C.prefix(version) and C.active[version].id end
function C.detach(version)
 local r,why=registry();if not r then return nil,why end
 local id=account();if r.accounts[id or ''] then r.accounts[id][version]=nil end
 local ok,err=Safety.atomicWrite(disk(),C.REGISTRY,S.encode(r),{decode=S.decode})
 if ok then C.refresh() end;return ok,err
end
local function allowed(store)
 if not store or store.kind~='retro' then return nil,'Use your RetroRecomped account for private games.' end
 return require('src.storage.AccountStorage').storeCheck(store)
end
local function contract(version) return require('src.import.RomImporter').cacheContract(version) end
local function complete(m)
 local present,absent={},{}
 for _,f in ipairs(m.files) do present[f.path]=true end
 for line in m.marker:gmatch('[^\r\n]+') do local p=line:match('^absent:(.+)$');if p then absent[p]=true end end
 for _,p in ipairs(contract(m.version).files) do
  if p~='rom-cache.complete' and not absent[p] and not present[p] then return nil,'Private game is missing '..p end
 end
 for _,name in ipairs({'constants','pokemon','moves','items','maps','trainers','encounters','type_chart'}) do
  if not present['data/generated/'..name..'.lua'] then return nil,'Private game is missing its core '..name..' data.' end
 end
 return true
end
local function fullMarker(version,fs)
 return fs.read(Versions.cachePrefix(version)..'rom-cache.complete')
end
local function capture(version,fs,progress)
 local expected=contract(version).marker;local marker=fullMarker(version,fs)
 if type(marker)~='string' or marker:match('^[^\r\n]+')~=expected then return nil,'Import this game with the current engine before uploading it.' end
 local prefix=Versions.cachePrefix(version);local files,total={},0
 local function walk(path,depth)
  if depth>24 then error('Imported data directory depth limit.',0) end
  local names=fs.getDirectoryItems(prefix..path) or {};table.sort(names)
  for _,name in ipairs(names) do
   local p=path..'/'..name;local info=fs.getInfo(prefix..p)
   if info and info.type=='directory' then walk(p,depth+1)
   elseif info and (info.type=='file' or info.type==nil) then
    -- Locally compiled LuaJIT caches are architecture-specific. The checked
    -- Lua source travels instead; the target builds its own bytecode cache.
    local source=p:match('^(data/generated/[%w_/%-]+%.lua)c$') or p:match('^(data/generated/[%w_/%-]+%.lua)c%.meta$')
    local compiled=source and fs.getInfo(prefix..source)
    if not compiled then
    if not C.path(p) then error('Unsupported imported file: '..p,0) end
    local bytes=fs.read(prefix..p);local ok,why=C.validateFile(p,bytes);if not ok then error(why,0) end
    files[#files+1]={path=p,size=#bytes,sha256=hash(bytes)};total=total+#bytes
    if total>C.MAX_TOTAL or #files>C.MAX_FILES then error('Private game exceeds the transfer limit.',0) end
    tick('Checking '..version..' · '..#files..' files',progress)
    end
   end
  end
 end
 local ok,why=pcall(function() walk('data/generated',0);walk('assets/generated',0) end)
 if not ok then return nil,why end
 table.sort(files,function(a,b) return a.path<b.path end)
 local offset=0;for _,f in ipairs(files) do f.offset=offset;offset=offset+f.size end
 if #files==0 then return nil,'This game has no imported data.' end
 local m={schema=1,version=version,rom=Versions.info(version).sha1,marker=marker,total=total,files=files,blocks={}}
 local good,err=complete(m);if not good then return nil,err end
 return m,prefix
end
function C.upload(store,version,progress,fs)
 local ok,why=allowed(store);if not ok then return nil,why end
 if not Versions.VERSIONS[version] then return nil,'Unknown game.' end
 fs=fs or disk();local m,prefix=capture(version,fs,progress);if not m then return nil,prefix end
 local buffer=''
 local function block(raw)
  local bytes=S.encode({schema=1,size=#raw,sha256=hash(raw),data=love.data.encode('string','base64',raw)})
  local id=hash(bytes);local path='game-cache/blobs/'..id..'.lua';local prior=store.read(path)
  if prior and prior~=bytes then error('Private game block conflict.',0) end
  if not prior then local good,err=store.write(path,bytes);if not good then error(err,0) end end
  m.blocks[#m.blocks+1]={id=id,size=#raw};tick('Uploading '..version..' · '..#m.blocks..' blocks',progress)
 end
 for _,f in ipairs(m.files) do
  local bytes=fs.read(prefix..f.path)
  if not bytes or #bytes~=f.size or hash(bytes)~=f.sha256 then return nil,'The imported game changed during upload. Retry after the import finishes.' end
  local p=1
  while p<=#bytes do
   local n=math.min(C.BLOCK-#buffer,#bytes-p+1);buffer=buffer..bytes:sub(p,p+n-1);p=p+n
   if #buffer==C.BLOCK then block(buffer);buffer='' end
  end
 end
 if #buffer>0 then block(buffer) end
 if fullMarker(version,fs)~=m.marker then return nil,'The import changed before the upload could be published.' end
 ok,why=allowed(store);if not ok then return nil,why end
 local bytes=S.encode(m);local valid,err=C.decode(bytes);if not valid then return nil,err end
 local id=hash(bytes);local path='game-cache/manifests/'..version..'/'..id..'.lua'
 local prior=store.read(path);if prior and prior~=bytes then return nil,'Private manifest conflict.' end
 if not prior then ok,why=store.write(path,bytes);if not ok then return nil,why end end
 local head='game-cache/heads/'..version..'.lua'
 local current=store.read(head);local nextHead=S.encode({schema=1,version=version,manifest=id})
 if current~=nextHead then ok,why=store.write(head,nextHead);if not ok then return nil,why end end
 return id
end
function C.restore(store,version,id,progress,fs)
 local ok,why=allowed(store);if not ok then return nil,why end
 if not Versions.VERSIONS[version] then return nil,'Unknown private game.' end
 fs=fs or disk()
 if not id then
  local head=parse(store.read('game-cache/heads/'..version..'.lua'),4096)
  if not head then return nil,'No private cloud copy for this game.' end
  if head.schema~=1 or head.version~=version or not digest(head.manifest) then return nil,'Invalid private game head.' end
  id=head.manifest
 end
 if not digest(id) then return nil,'Invalid private game identity.' end
 local bytes=store.read('game-cache/manifests/'..version..'/'..id..'.lua')
 if not bytes or hash(bytes)~=id then return nil,'Private game manifest fingerprint mismatch.' end
 local m,err=C.decode(bytes);if not m then return nil,err end
 if m.version~=version or m.marker:match('^[^\r\n]+')~=contract(version).marker then return nil,'This private game needs a different engine/import revision.' end
 ok,why=complete(m);if not ok then return nil,why end
 local owner=account();if type(owner)~='string' or not owner:match('^[1-9][0-9]*$') then return nil,'A registered account is required.' end
 local root='launcher/private_games/'..owner..'/'..id..'/'
 local staging=root..'blocks/';local fileIndex,pieces,filled=1,{},0
 for i,b in ipairs(m.blocks) do
  ok,why=allowed(store);if not ok then return nil,why end
  local path=staging..b.id..'.lua';local payload=fs.read(path)
  if not payload or hash(payload)~=b.id then payload=store.read('game-cache/blobs/'..b.id..'.lua') end
  if not payload or hash(payload)~=b.id then return nil,'Private game block fingerprint mismatch.' end
  local chunk=parse(payload,2*C.BLOCK)
  if not chunk or chunk.schema~=1 or chunk.size~=b.size or type(chunk.data)~='string' or #chunk.data>math.ceil(C.BLOCK/3)*4 or not digest(chunk.sha256) then return nil,'Invalid private game block.' end
  local decoded,raw=pcall(love.data.decode,'string','base64',chunk.data)
  if not decoded or type(raw)~='string' or #raw~=b.size or hash(raw)~=chunk.sha256 then return nil,'Private game block data mismatch.' end
  fs.createDirectory(staging);ok,why=fs.write(path,payload);if not ok then return nil,why end
  local p=1
  while fileIndex<=#m.files and (p<=#raw or m.files[fileIndex].size==0) do
   local f=m.files[fileIndex];local n=math.min(f.size-filled,#raw-p+1)
   pieces[#pieces+1]=raw:sub(p,p+n-1);filled=filled+n;p=p+n
   if filled==f.size then
    local data=table.concat(pieces)
    if hash(data)~=f.sha256 then return nil,'Private game file fingerprint mismatch.' end
    local good,problem=C.validateFile(f.path,data);if not good then return nil,problem end
    fs.createDirectory((root..f.path):match('^(.*)/[^/]+$'))
    ok,why=fs.write(root..f.path,data);if not ok then return nil,why end
    fileIndex=fileIndex+1;pieces={};filled=0
   end
  end
  tick('Restoring '..version..' · '..i..' / '..#m.blocks,progress)
 end
 if fileIndex~=#m.files+1 then return nil,'Private game download is incomplete.' end
 ok,why=allowed(store);if not ok then return nil,why end
 if account()~=owner then return nil,'The account changed. No private game was activated.' end
 fs.createDirectory(root);ok,why=fs.write(root..'manifest.lua',bytes);if not ok then return nil,why end
 ok,why=fs.write(root..'rom-cache.complete',m.marker);if not ok then return nil,why end
 -- Publish a pointer into a new immutable directory. Existing imports and
 -- all saves remain untouched, even after cancellation or interrupted I/O.
 local r,problem=registry();if not r then return nil,problem end
 r.accounts[owner]=r.accounts[owner] or {};r.accounts[owner][version]=id
 ok,why=Safety.atomicWrite(disk(),C.REGISTRY,S.encode(r),{decode=S.decode});if not ok then return nil,why end
 C.refresh()
 for _,b in ipairs(m.blocks) do fs.remove(staging..b.id..'.lua') end
 return id
end
function C.sync(store,options,ready,progress,forceUpload)
 local ok,why=allowed(store);if not ok then return nil,why end
 local stateFs=require('src.core.SaveData').persistenceFs()
 local raw=stateFs.read(C.STATE);local st=raw and parse(raw,128*1024)
 if raw and (not st or st.schema~=1 or type(st.games)~='table') then return nil,'Private game sync journal needs recovery.' end
 st=st or {schema=1,games={}};local result={uploaded=0,downloaded=0,versions={}}
 for _,v in ipairs(Versions.ORDER) do
  local head='game-cache/heads/'..v..'.lua'
  if not ready[v] and options.gameCacheDownload~=false and (not store.has or store.has(head)) then
   local bytes=store.read(head)
   if bytes then
    local id,err=C.restore(store,v,nil,progress);if not id then return nil,err end
    result.downloaded=result.downloaded+1;result.versions[#result.versions+1]=v
   end
  elseif ready[v] and (options.gameCacheUpload or forceUpload) then
   local marker=fullMarker(v,disk());local old=st.games[v]
   local remote=(not store.has or store.has(head)) and parse(store.read(head),4096)
   if forceUpload or not old or old.marker~=marker or not remote or remote.manifest~=old.id then
    local id,err=C.upload(store,v,progress);if not id then return nil,err end
    st.games[v]={id=id,marker=marker};result.uploaded=result.uploaded+1
    local saved,problem=Safety.atomicWrite(stateFs,C.STATE,S.encode(st),{decode=S.decode});if not saved then return nil,problem end
   end
  end
 end
 return result
end
return C
