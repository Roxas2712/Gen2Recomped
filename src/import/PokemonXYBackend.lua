-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A fresh library must not depend on an already imported private game.
local B={}
local files={'pokemon_x_backend.py','pokemon_x_preflight.py','pokemon_xy_library.py','pokemon_xy_runtime.py','native_workspace.py',
 'qa_storage.py','qa_legacy_storage.py','qa_love_storage.py','qa_preserved.py',
 'qa_release_storage.py','qa_build_storage.py'}
local cached
function B.exists(path)
 if love.system and love.system.getOS()=='Windows'then
  local stream=require('src.core.NativeFile').openRead(path)
  if stream then stream:close();return true end;return false
 end
 local file=io.open(path,'rb');if file then file:close();return true end
 return false
end
local exists=B.exists
function B.runtime()
 local explicit=os.getenv('POKEMON_XY_RUNTIME_ROOT')
 local source=love.filesystem.getSource and love.filesystem.getSource()
 local base=love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory()
 local parent=source and source:match('^(.*)/[^/]+$')
 for _,path in ipairs{explicit or false,parent and (parent..'/3ds-runtime') or false,base and (base..'/3ds-runtime') or false}do
  if path and exists(path..'/runtime.json') then return path end
 end
end
function B.file(kind)
 local root=B.runtime();if not root then return end
 local windows=love.system and love.system.getOS()=='Windows'
 local paths=windows and {python='python/python.exe',bridge='lib/ascendant_3ds_bridge.dll'}
  or{python='python/bin/python3.12',bridge='lib/libascendant_3ds_bridge.dylib'}
 return paths[kind]and(root..'/'..paths[kind])
end
function B.root()
 if cached then return cached end
 local explicit=os.getenv('POKEMON_XY_ROOT')
 if explicit then
  if exists(explicit..'/tools/pokemon_x_backend.py') then return explicit end
  return nil,'The configured 3DS backend folder is missing its import tools.'
 end
 local source=love.filesystem.getSource and love.filesystem.getSource()
 if source and exists(source..'/tools/pokemon_x_backend.py')then return source end
 -- Python cannot execute a script inside game.love. Extract only the reviewed
 -- helper sources; game data and binaries are never part of this payload.
 local base='pokemon-xy-backend'
 local data={}
 for _,name in ipairs(files)do
  local body=love.filesystem.read('tools/'..name)
  if not body then return nil,'The 3DS import tools are missing from this application.' end
  data[name]=body
 end
 local ok,why=love.filesystem.createDirectory(base..'/tools')
 if not ok then return nil,why end
 for _,name in ipairs(files)do
  local written,err=love.filesystem.write(base..'/tools/'..name,data[name])
  if not written then return nil,err end
 end
 cached=love.filesystem.getSaveDirectory()..'/'..base
 return cached
end
return B
