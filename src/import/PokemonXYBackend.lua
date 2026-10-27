-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A fresh library must not depend on an already imported private game.
local B={}
local files={'pokemon_x_backend.py','pokemon_x_preflight.py','pokemon_xy_library.py',
 'qa_storage.py','qa_legacy_storage.py','qa_love_storage.py','qa_preserved.py',
 'qa_release_storage.py','qa_build_storage.py'}
local cached
local function exists(path)
 local file=io.open(path,'rb');if file then file:close();return true end
 return false
end
function B.root()
 if cached then return cached end
 local explicit=os.getenv('POKEMON_XY_ROOT')
 if explicit then
  if exists(explicit..'/tools/pokemon_x_backend.py') then return explicit end
  return nil,'The configured 3DS backend folder is missing its import tools.'
 end
 local source=love.filesystem.getSource()
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
