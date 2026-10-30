-- TCG-specific mod API 1. Contributions by Roxas2712.
local Json=require('src.link.Json')
local M={API=1};local H={};H.__index=H
local ROOT='tcg-mods'
local function id(v)return type(v)=='string'and #v<=64 and v:match('^[a-z0-9][a-z0-9_-]*$')end
local function path(v)return type(v)=='string'and #v<=200 and v~=''and not v:find('[\\:%c]')and v:sub(1,1)~='/'and not('/'..v..'/'):find('/%.%./')and not('/'..v..'/'):find('/%./')end
local function hash(s)
 local major=love.getVersion and love.getVersion()or 11
 local bytes=major>=12 and love.data.hash('string','sha256',s)or love.data.hash('sha256',s)
 return love.data.encode('string','hex',bytes)
end
local function copy(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
local function enabled(fs)
 local raw=fs.read(ROOT..'/enabled.json');if not raw then return{}end
 local ok,v=pcall(Json.decode,raw);assert(ok and type(v)=='table','Invalid TCG enabled-mod list');return v
end
function M.list(fs)
 fs=fs or love.filesystem;local flags=enabled(fs);local out={}
 for _,folder in ipairs(fs.getDirectoryItems(ROOT)or{})do
  if id(folder)and fs.getInfo(ROOT..'/'..folder..'/manifest.json')then
   local raw=assert(fs.read(ROOT..'/'..folder..'/manifest.json'));assert(#raw<=16384,'TCG mod manifest too large')
   local v=Json.decode(raw)
   assert(type(v)=='table'and v.id==folder and v.game=='tcggbc'and v.api==1 and type(v.version)=='string'and #v.version<=32,'Invalid TCG mod manifest: '..folder)
   assert(v.online=='cosmetic'or v.online=='disabled','TCG mod must declare online cosmetic/disabled')
   v.enabled=flags[folder]==true;out[#out+1]=v
  end
 end
 table.sort(out,function(a,b)return a.id<b.id end);return out
end
function M.toggle(modId,fs)
 assert(id(modId),'Invalid TCG mod id');fs=fs or love.filesystem
 local flags=enabled(fs);flags[modId]=not flags[modId];fs.createDirectory(ROOT);assert(fs.write(ROOT..'/enabled.json',Json.encode(flags)));return flags[modId]
end
local function files(fs,root)
 local result={};local total,count=0,0
 local function walk(dir,relative,depth)
  assert(depth<=8,'TCG mod nesting limit')
  local names=fs.getDirectoryItems(dir)or{};table.sort(names)
  for _,name in ipairs(names)do
   assert(path(name)and not name:find('/'),'Invalid TCG mod file name')
   local p=dir..'/'..name;local rel=relative==''and name or relative..'/'..name;local info=assert(fs.getInfo(p))
   if info.type=='directory'then walk(p,rel,depth+1)
   else
    assert(info.type=='file'and(info.size or 0)<=1024*1024,'TCG mod file exceeds 1 MiB')
    local bytes=assert(fs.read(p));total=total+#bytes;count=count+1;assert(total<=16*1024*1024 and count<=128,'TCG mod content limit')
    result[rel]=bytes
   end
  end
 end
 walk(root,'',0);return result
end
local function call(fn,...)
 local old,mask,count=debug.gethook();local remaining=100000
 debug.sethook(function()remaining=remaining-1000;if remaining<=0 then error('TCG mod instruction budget exceeded')end end,'',1000)
 local ok,why=pcall(fn,...);debug.sethook(old,mask,count);assert(ok,why)
end
function M.new(host,online,options)
 options=options or{};local fs=options.fs or love.filesystem;local self=setmetatable({host=host,online=online,mods={},commands={},images={},errors={},hash=options.hash or hash},H)
 local signature={'tcg-api-1'}
 for _,manifest in ipairs(M.list(fs))do if manifest.enabled then
  assert(not online or manifest.online=='cosmetic','TCG mod '..manifest.id..' is solo-only')
  local capabilities={};for _,name in ipairs(manifest.capabilities or{})do assert(name=='memory.read'or name=='memory.write'or name=='overlay','Unknown TCG mod capability');capabilities[name]=true end
  assert(not online or not capabilities['memory.write'],'TCG memory-writing mods are solo-only')
  local bytes=files(fs,ROOT..'/'..manifest.id);local names={};for name in pairs(bytes)do names[#names+1]=name end;table.sort(names)
  signature[#signature+1]=manifest.id..'\0'..manifest.version
  for _,name in ipairs(names)do signature[#signature+1]=name..'\0'..self.hash(bytes[name])end
  local mod={id=manifest.id,callbacks={},files=bytes,capabilities=capabilities};self.mods[#self.mods+1]=mod
  local api={version=1,game='tcggbc'}
  function api.on(event,fn)
   assert(event=='start'or event=='frame'or event=='draw'or event=='link'or event=='stop','Unknown TCG event');assert(type(fn)=='function','Callback required')
   local rows=mod.callbacks[event]or{};assert(#rows<16,'Too many TCG callbacks');mod.callbacks[event]=rows;rows[#rows+1]=fn
   return function()for i,f in ipairs(rows)do if f==fn then table.remove(rows,i);return end end end
  end
  function api.info()return host:modInfo()end
  api.memory={read=function(region,offset,length,seat)
   assert(capabilities['memory.read'],'TCG memory.read capability required');return host:modRead(region,offset,length,seat)
  end,write=function(region,offset,data)
   assert(not online and capabilities['memory.write'],'TCG memory writes require a solo session and memory.write capability')
   assert(self.phase=='frame'or self.phase=='start','TCG memory writes are only allowed at frame boundaries');return host:modWrite(region,offset,data)
  end}
  api.assets={read=function(relative)assert(path(relative),'Invalid TCG asset path');return assert(bytes[relative],'TCG asset not found')end}
  local function command(kind,row)
   assert(capabilities.overlay and self.phase=='draw','TCG drawing requires overlay capability and a draw callback')
   assert(#self.commands<256,'TCG overlay command limit');row.kind=kind;row.owner=mod;self.commands[#self.commands+1]=row
  end
  local function number(n)assert(type(n)=='number'and n==n and math.abs(n)<=4096,'Invalid TCG draw coordinate');return n end
  local function color(c)c=c or{1,1,1,1};local out={};for i=1,4 do local n=c[i]or 1;assert(type(n)=='number'and n>=0 and n<=1,'Invalid TCG color');out[i]=n end;return out end
  api.draw={text=function(text,x,y,c)assert(type(text)=='string'and #text<=512,'TCG text exceeds limit');command('text',{text=text,x=number(x),y=number(y),color=color(c)})end,
   rectangle=function(x,y,w,h,c)command('rectangle',{x=number(x),y=number(y),w=number(w),h=number(h),color=color(c)})end,
   image=function(relative,x,y,scale)assert(path(relative)and bytes[relative],'Invalid TCG image');command('image',{path=relative,x=number(x),y=number(y),scale=number(scale or 1),color={1,1,1,1}})end}
  api.log=function(message)assert(type(message)=='string'and #message<=1024,'Invalid TCG log message');print('[TCG mod '..manifest.id..'] '..message)end
  local safeMath=copy(math);safeMath.random=nil;safeMath.randomseed=nil
  local safeString=copy(string);safeString.dump=nil
  local env={api=api,assert=assert,error=error,ipairs=ipairs,pairs=pairs,next=next,tonumber=tonumber,tostring=tostring,type=type,select=select,unpack=unpack,math=safeMath,string=safeString,table=copy(table)}
  local source=assert(bytes['main.lua'],'TCG mod main.lua missing');assert(source:byte(1)~=27,'TCG mods must be text source')
  local fn,why
  if setfenv then fn,why=loadstring(source,'@tcg-mod:'..manifest.id);assert(fn,why);setfenv(fn,env)else fn,why=load(source,'@tcg-mod:'..manifest.id,'t',env);assert(fn,why)end
  if jit then jit.off(fn,true)end
  call(fn)
 end end
 self.signature=self.hash(table.concat(signature,'\n'));return self
end
function H:emit(event,data)
 self.phase=event
 local ok,why=pcall(function()
  for _,mod in ipairs(self.mods)do for _,fn in ipairs(mod.callbacks[event]or{})do
   local eventData=copy(data or{});local passed,problem=pcall(call,fn,eventData);assert(passed,'TCG mod '..mod.id..': '..tostring(problem))
  end end
 end)
 self.phase=nil;assert(ok,why)
end
function H:draw()
 self.commands={};self:emit('draw',self.host:modInfo());local g=love.graphics
 if #self.commands==0 then return end
 self.font=self.font or g.newFont(8);g.setFont(self.font)
 for _,row in ipairs(self.commands)do
  g.setColor(unpack(row.color))
  if row.kind=='text'then g.print(row.text,row.x,row.y)
  elseif row.kind=='rectangle'then g.rectangle('fill',row.x,row.y,row.w,row.h)
  else
   local key=row.owner.id..'/'..row.path;local img=self.images[key]
   if not img then
    local file=love.filesystem.newFileData(row.owner.files[row.path],row.path);local data=love.image.newImageData(file);file:release()
    assert(data:getWidth()<=1024 and data:getHeight()<=1024,'TCG overlay image dimensions exceed limit');img=g.newImage(data);data:release();img:setFilter('nearest','nearest');self.images[key]=img
   end
   g.draw(img,row.x,row.y,0,row.scale,row.scale)
  end
 end
end
function H:close()
 local ok,why=pcall(self.emit,self,'stop',self.host:modInfo())
 for _,img in pairs(self.images)do img:release()end;if self.font then self.font:release()end
 self.mods={};self.images={};self.commands={};self.host=nil;return ok,why
end
return M
