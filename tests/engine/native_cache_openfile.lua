package.path='./?.lua;'..package.path
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
package.loaded['src.core.SaveData']={portableBaseDir=function()end,dataDir=function()end}
local files,calls={},{}
love={filesystem={getSource=function()return'/virtual/game'end}}
local function opened(path,mode)
 calls[#calls+1]={path,mode}
 if mode=='w'then files[path]=''elseif not files[path]then return nil,'missing input'end
 local position=0
 return{
  open=function()error('openFile returned an already-open file')end,
  write=function(_,bytes)files[path]=files[path]..bytes;return true end,
  read=function(_,length)local bytes=files[path]:sub(position+1,length and position+length or-1);position=position+#bytes;return bytes end,
  seek=function(_,at)position=at;return true end,
  close=function()return true end,
 }
end
love.filesystem.openFile=opened
love.filesystem.newFile=function()error('deprecated LOVE 12 constructor defaults to read')end
local fs=require('src.import.CacheFs').dataFs()
local file=fs.newFile('imports/staging/new.part')
check(file:open('w'),'native writer creates a new staging file')
check(file:write('ROM\0bytes'),'native staged bytes are written')
check(file:close(),'native writer closes')
check(calls[1][2]=='w','LOVE 12 receives write mode at construction')
local reader=assert(fs.newFile('imports/staging/new.part','r'))
check(reader:read(3)=='ROM','already-open LOVE 12 read handle is consumed once')
check(reader:seek(0),'native reader can seek')
check(reader:read()=='ROM\0bytes','native ranged reader preserves binary bytes')
check(reader:close(),'native reader closes')
check(fs.newFile('missing','r')==nil,'absent input remains absent')
-- Stable LOVE 11.5 still constructs an unopened File then opens it once.
love.filesystem.openFile=nil
love.filesystem.newFile=function(path)
 local handle
 return{
  open=function(_,mode)handle=opened(path,mode);return handle~=nil end,
  write=function(_,...)return handle:write(...)end,
  read=function(_,...)return handle:read(...)end,
  close=function()return handle:close()end,
 }
end
local legacy=assert(fs.newFile('legacy.part','w'))
check(legacy:write('legacy'),'LOVE 11.5 writer still creates files')
check(legacy:close(),'LOVE 11.5 writer closes')
legacy=assert(fs.newFile('legacy.part','r'))
check(legacy:read()=='legacy','LOVE 11.5 input reads remain unchanged')
check(legacy:close(),'LOVE 11.5 reader closes')
love.filesystem.openFile=opened
love.filesystem.read=function(path)return files[path]end
love.filesystem.getInfo=function(path)return files[path]and{type='file',size=#files[path]}end
files['gold/data/generated/native-mode.lua']='gold cache'
local Cache=require('src.import.CacheFs')
Cache.installPrefixShim('gold/')
local scoped=assert(fs.newFile('data/generated/native-mode.lua','r'))
check(scoped:read()=='gold cache','LOVE 12 native reads retain the selected edition prefix')
check(scoped:close(),'prefixed native read closes')
Cache.clearPrefixShim()
files['data/generated/native-mode.lua']='root cache'
scoped=assert(fs.newFile('data/generated/native-mode.lua','r'))
check(scoped:read()=='root cache','edition teardown makes the native read wrapper inert')
check(scoped:close(),'root native read closes after teardown')
print(('Native file modes: %d checks passed'):format(checks))
