-- Local visual packs; rules, accounts, scores and rewards never come from a pack.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C={ROOT='minigames/content',FILE='minigames/content/selection.lua',VERSION=1,
 MAX_FILES=2048,MAX_TOTAL=64*1024*1024,MAX_DIMENSION=2048,MAX_PIXELS=4*1024*1024,MAX_TOTAL_PIXELS=16*1024*1024}
local Data=require('src.import.PackData')
local Writer=require('src.import.LuaWriter')
local MD5=require('src.mods.StreamMD5')
local Publish=require('src.import.PackPublish')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local function hash(bytes)return MD5.new():update(bytes):final()end
local function fs()return Saves.persistenceFs()end
local function publish(f,path,bytes)
 if not(f and f.write and f.createDirectory)then return nil,'Local content storage is unavailable.'end
 local parent=path:match('^(.*)/[^/]+$')
 if parent then local ok,why=f.createDirectory(parent);if not ok then return nil,why end end
 if f and f.rename then return Publish(f,path,bytes)end
 -- LÖVE itself has no rename; SaveSafety supplies verified staging and the
 -- same real-path atomic rename already used by saves, including ProfileFs.
 return Safety.atomicWrite(f,path,bytes,{decode=function(v)return type(v)=='string'and v~=''and v or nil end})
end
local function scope(expected)return expected==fs()end
local function utf8(v)
 local i=1
 while i<=#v do
  local b=v:byte(i);local length,lo,hi=1,128,191
  if b>=194 and b<=223 then length=2
  elseif b>=224 and b<=239 then length=3;if b==224 then lo=160 elseif b==237 then hi=159 end
  elseif b>=240 and b<=244 then length=4;if b==240 then lo=144 elseif b==244 then hi=143 end
  elseif b>=128 then return false end
  if i+length-1>#v then return false end
  if length>1 then
   local second=v:byte(i+1);if second<lo or second>hi then return false end
   for at=i+2,i+length-1 do local c=v:byte(at);if c<128 or c>191 then return false end end
  end
  i=i+length
 end
 return true
end
local function text(v,n)return type(v)=='string'and #v>0 and #v<=(n or 512)and not v:find('[%z\1-\8\11\12\14-\31]')and utf8(v)end
local function path(v)return text(v,256)and v:match('^[a-z0-9_/%.-]+$')and not v:find('..',1,true)and v:sub(1,1)~='/'and not v:find('//',1,true)end
local function integer(v,a,b)return type(v)=='number'and v%1==0 and v>=a and v<=b end
local function dense(v,limit)
 if type(v)~='table'then return false end
 local n=0;for k in pairs(v)do if not integer(k,1,limit)then return false end;n=n+1 end
 return n==#v and n<=limit
end
local function png(bytes)
 if type(bytes)~='string'or #bytes<24 or bytes:sub(1,8)~='\137PNG\13\10\26\10'or bytes:sub(13,16)~='IHDR'then return nil end
 local function be(i)local a,b,c,d=bytes:byte(i,i+3);return ((a*256+b)*256+c)*256+d end
 local w,h=be(17),be(21)
 if not integer(w,1,C.MAX_DIMENSION)or not integer(h,1,C.MAX_DIMENSION)or w*h>C.MAX_PIXELS then return nil end
 return w,h
end
C.png=png
function C.validate(m)
 if type(m)~='table'or m.format~=1 or not text(m.name,96)or not text(m.source,512)
  or not text(m.credits,2048)or not text(m.terms,2048)or not dense(m.entries,C.MAX_FILES)or #m.entries==0 then return nil,'Invalid minigame content manifest.'end
 local keys,files,total,pixels={},{},0,0
 for _,e in ipairs(m.entries)do
  if type(e)~='table'or not path(e.key)or keys[e.key]or not path(e.file)or e.file:sub(-4)~='.png'
   or not integer(e.size,24,Data.MAX_BYTES)or type(e.md5)~='string'or not e.md5:match('^[a-f0-9]+$')or #e.md5~=32
   or not integer(e.width,1,C.MAX_DIMENSION)or not integer(e.height,1,C.MAX_DIMENSION)or e.width*e.height>C.MAX_PIXELS then return nil,'Invalid minigame content entry.'end
  -- Sprite keys are national-dex identities, never code or reward definitions.
  if not e.key:match('^front/%d+$')and not e.key:match('^walk/%d+$')then return nil,'Unknown minigame content key.'end
  keys[e.key]=true
  local id=tonumber(e.key:match('/(%d+)$'));if not integer(id,1,65535)then return nil,'Invalid minigame content entry.'end
  local prior=files[e.file];local identity=e.size..':'..e.md5
  if prior and prior~=identity then return nil,'Conflicting minigame content files.'end
  if not prior then total=total+e.size;pixels=pixels+e.width*e.height;files[e.file]=identity end
  if total>C.MAX_TOTAL or pixels>C.MAX_TOTAL_PIXELS then return nil,'Minigame content exceeds the size limit.'end
  if e.key:sub(1,5)=='walk/'then
   if not integer(e.frameWidth,1,e.width)or not integer(e.frameHeight,1,e.height)or e.width%e.frameWidth~=0 or e.height%e.frameHeight~=0 then return nil,'Invalid minigame animation.'end
   local count=(e.width/e.frameWidth)*(e.height/e.frameHeight)
   if type(e.facings)~='table'then return nil,'Invalid minigame animation.'end
   for _,dir in ipairs{'up','down','left','right'}do
    local frames=e.facings[dir];if not dense(frames,64)or #frames==0 then return nil,'Invalid minigame animation.'end
    for _,v in ipairs(frames)do if not integer(v,0,count-1)then return nil,'Invalid minigame animation.'end end
   end
  end
 end
 return true
end
local function readSelection(f)
 local bytes=Data.read(f,C.FILE);if not bytes then return nil end
 local m=Data.decode(bytes)
 if type(m)~='table'or m.version~=C.VERSION or m.noticeVersion~=require('src.pokewalker.minigames.Enrollment').VERSION or m.accepted~=true then return nil end
 if m.mode=='basic'then return m end
 if m.mode~='pack'or type(m.digest)~='string'or #m.digest~=32 or m.digest:find('[^a-f0-9]')then return nil end
 local bytes=Data.read(f,C.ROOT..'/packs/'..m.digest..'.lua')
 if not bytes or hash(bytes)~=m.digest then return nil end
 local manifest=Data.decode(bytes)
 if not C.validate(manifest)then return nil end
 m.manifest=manifest;return m
end
function C.current()return readSelection(fs())end
function C.basic(expected)
 if not scope(expected)then return nil,'The content profile changed. Reopen setup.'end
 return publish(expected,C.FILE,Writer.encode({version=C.VERSION,noticeVersion=require('src.pokewalker.minigames.Enrollment').VERSION,mode='basic',accepted=true}))
end
function C.revoke()
 return publish(fs(),C.FILE,Writer.encode({version=C.VERSION,accepted=false}))
end
-- Review is read-only. No bytes are installed until a separate explicit accept.
function C.review(source,root)
 root=root or'';if root~=''and not path(root)then return nil,'Invalid minigame content path.'end
 local prefix=root==''and''or root..'/'
 local bytes,err=Data.read(source,prefix..'minigames.lua');if not bytes then return nil,err end
 local m;m,err=Data.decode(bytes);if not m then return nil,err end
 local ok;ok,err=C.validate(m);if not ok then return nil,err end
 return {manifest=m,bytes=bytes,digest=hash(bytes),source=source,prefix=prefix,profile=fs(),noticeVersion=require('src.pokewalker.minigames.Enrollment').VERSION}
end
function C.install(review,permission)
 return coroutine.create(function()
  assert(permission==true,'Confirm permission before preparing additional content.')
  assert(scope(review.profile),'The content profile changed. Reopen setup.')
  assert(review.noticeVersion==require('src.pokewalker.minigames.Enrollment').VERSION,'The profile or notices changed. Read them again before accepting.')
  local reviewed=assert(Data.decode(review.bytes))
  assert(hash(review.bytes)==review.digest and Writer.encode(review.manifest)==Writer.encode(reviewed),'Minigame content changed during review.')
  assert(C.validate(review.manifest))
  local f=review.profile;local total,copied=0,{}
  for i,e in ipairs(review.manifest.entries)do
   assert(scope(f),'The content profile changed. Reopen setup.')
   local bytes,why=Data.read(review.source,review.prefix..e.file,e.size);assert(bytes,why)
   assert(hash(bytes)==e.md5,'Minigame content file changed or is incomplete.')
   local w,h=png(bytes);assert(w==e.width and h==e.height,'Invalid minigame image dimensions.')
   -- Decode before publication, with dimensions bounded before allocation.
   local image=love.image.newImageData(love.filesystem.newFileData(bytes,'content.png'))
   assert(image:getWidth()==w and image:getHeight()==h,'Invalid minigame image dimensions.')
   if image.release then image:release()end
   local target=C.ROOT..'/objects/'..e.md5..'.png'
   if not copied[e.md5]then
    if Data.read(f,target,e.size)~=bytes then assert(publish(f,target,bytes))end
    total=total+#bytes;copied[e.md5]=bytes
   else assert(copied[e.md5]==bytes,'Conflicting minigame content files.')end
   assert(total<=C.MAX_TOTAL,'Minigame content exceeds the size limit.')
   coroutine.yield({done=i,total=#review.manifest.entries})
  end
  assert(scope(f),'The content profile changed. Reopen setup.')
  assert(review.noticeVersion==require('src.pokewalker.minigames.Enrollment').VERSION,'The profile or notices changed. Read them again before accepting.')
  for digest,bytes in pairs(copied)do
   assert(Data.read(f,C.ROOT..'/objects/'..digest..'.png',#bytes)==bytes,'Minigame content file changed or is incomplete.')
  end
  assert(publish(f,C.ROOT..'/packs/'..review.digest..'.lua',review.bytes))
  assert(publish(f,C.FILE,Writer.encode({version=C.VERSION,noticeVersion=require('src.pokewalker.minigames.Enrollment').VERSION,mode='pack',accepted=true,digest=review.digest,acceptedAt=os.time()})))
  return true
 end)
end
-- Snapshot the existing local import; never download assets or modify its cache.
function C.prepare(version,Art)
 local expected=fs()
 return coroutine.create(function()
  Art=Art or require('src.pokewalker.WalkerArt')
  local roster=Art.roster(version);assert(type(roster)=='table'and #roster>0,'Import a game first, or use basic graphics.')
  local files,entries,total={},{},0
  local function add(key,img,fw,fh,facings)
   if not img then return end
   assert(#entries<C.MAX_FILES,'Minigame content exceeds the size limit.')
   local bytes=Art.bytes(img);assert(type(bytes)=='string','Imported image bytes are unavailable.')
   local w,h=png(bytes);assert(w and h,'Invalid imported image dimensions.')
   local digest=hash(bytes);local name='objects/'..digest..'.png'
   if not files[name]then total=total+#bytes;assert(total<=C.MAX_TOTAL,'Minigame content exceeds the size limit.');files[name]=bytes end
   entries[#entries+1]={key=key,file=name,size=#bytes,md5=digest,width=w,height=h,frameWidth=fw,frameHeight=fh,facings=facings}
  end
  for i,e in ipairs(roster)do
   assert(scope(expected),'The content profile changed. Reopen setup.')
   local front=Art.front(e.dex,false,version);add('front/'..e.dex,front)
   local img,fw,fh,facings=Art.walk(e.dex,false,version);add('walk/'..e.dex,img,fw,fh,facings)
   coroutine.yield({done=i,total=#roster})
  end
  local label=require('src.core.GameVersion').info(version)
  local manifest={format=1,name=(label and label.label or version)..' · local graphics',source='Local imported game: '..version,
   credits='Game content: respective rights holders. Local preparation does not grant additional rights.',
   terms='Use only when permitted for this purpose. No third-party content licence is supplied by this project.',entries=entries}
  assert(C.validate(manifest))
  files['minigames.lua']=Writer.encode(manifest)
  local source={getInfo=function(p)local b=files[p];return b and{type='file',size=#b}end,read=function(p)return files[p]end}
  local r=assert(C.review(source));assert(r.profile==expected,'The content profile changed. Reopen setup.')
  return r
 end)
end
function C.provider(selection)
 selection=selection or C.current()
 if not selection or selection.mode~='pack'then return nil end
 local owner=fs();local images,entries={},{}
 for _,e in ipairs(selection.manifest.entries)do entries[e.key]=e end
 local function image(key)
  if not scope(owner)then return nil end
  local e=entries[key];if not e then return nil end
  if images[key]==false then return nil end
  if images[key]then return images[key],e end
  local bytes=Data.read(owner,C.ROOT..'/objects/'..e.md5..'.png',e.size)
  if not bytes or hash(bytes)~=e.md5 then images[key]=false;return nil end
  local w,h=png(bytes);if w~=e.width or h~=e.height then images[key]=false;return nil end
  local ok,img=pcall(function()return love.graphics.newImage(love.filesystem.newFileData(bytes,'content.png'))end)
  if not ok then images[key]=false;return nil end
  img:setFilter('nearest','nearest');images[key]=img;return img,e
 end
 return {bounds=function()return nil end,front=function(dex)local img=image('front/'..dex);return img end,
  walk=function(dex)local img,e=image('walk/'..dex);if img then return img,e.frameWidth,e.frameHeight,e.facings end end,
  forget=function()images={}end}
end
return C
