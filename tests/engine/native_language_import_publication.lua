package.path='./?.lua;'..package.path
local files,dirs,deny={}, {},false
local function parent(path)return path:match('^(.*)/[^/]+$')end
local fs={}
function fs.createDirectory(path)
 if deny and path=='mods/language/baseroms'then return nil,'destination unavailable'end
 dirs[path]=true;return true
end
function fs.getInfo(path)
 if files[path]then return{type='file',size=#files[path],modtime=1}end
 if dirs[path]then return{type='directory'}end
end
function fs.readRange(path,at,length)return files[path]and files[path]:sub(at+1,at+length)end
function fs.read(path)return files[path]end
function fs.write(path,bytes)files[path]=bytes;return true end
function fs.remove(path)files[path]=nil;return true end
function fs.rename(from,to)
 if not dirs[parent(to)]then return nil,'missing destination parent'end
 files[to],files[from]=files[from],nil;return true
end
function fs.newFile(path)
 local mode
 return{open=function(_,value)
  mode=value
  if value=='w'then assert(dirs[parent(path)]);files[path]='';return true end
  return files[path]~=nil
 end,write=function(_,bytes)assert(mode=='w');files[path]=files[path]..bytes;return true end,close=function()return true end}
end
package.loaded['src.import.CacheFs']={dataFs=function()return fs end}
love={filesystem=fs,system={getOS=function()return'OS X'end}}
local Imports=require('src.mods.ModImports')
local entry=Imports.parse({optional_imports={{id='language',file='language.gbc',size=3,md5='900150983cd24fb0d6963f7d28e17f72'}}},'optional_imports')[1]
local manifest={path='mods/language'}
assert(not dirs['mods/language/baseroms'])
assert(Imports.install(manifest,entry,'abc'))
assert(files['mods/language/baseroms/language.gbc']=='abc','first native import is atomically published inside its declared folder')
assert(Imports.have(manifest,entry,fs),'published input is immediately discoverable through the launcher')
files['mods/language/baseroms/language.gbc']='OLD';deny=true
local ok,why=Imports.install(manifest,entry,'abc')
assert(not ok and why=='destination unavailable','destination creation failure is reported')
assert(files['mods/language/baseroms/language.gbc']=='OLD','failed publication preserves the previous private input')
print('Native language import: fresh destination, shared store, discovery and failed-publication preservation passed')
