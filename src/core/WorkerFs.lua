-- Worker Lua states do not inherit CacheFs's Switch filesystem shim.
local WorkerFs={}
function WorkerFs.prefix()
  -- Desktop workers share mounts, but their Lua module caches are independent.
  -- Send the originating edition explicitly so an in-process cartridge switch
  -- cannot reuse the previous edition's sound program under the same filename.
  return require('src.core.GameVersion').cachePrefix()
end
function WorkerFs.read(prefix,path)
  if prefix and prefix~='' then
    local bytes=love.filesystem.read(prefix..path)
    if bytes then return bytes end
  end
  return love.filesystem.read(path)
end
return WorkerFs
