-- Writable native Pinball installation; ROMs and generated libraries stay local.
local B={};local cached
local function exists(path)local f=io.open(path,'rb');if f then f:close();return true end;return false end
function B.root()
 local explicit=os.getenv('ASCENDANT_PINBALL_ROOT');if explicit then return explicit end
 if cached then return cached end
 local fs=love and love.filesystem
 if not fs or not fs.getSource then return end
 local source=fs.getSource();if source and exists(source..'/tools/pinball_rs.py')then return source end
 if not(fs.read and fs.write and fs.createDirectory and fs.getSaveDirectory)then return end
 local paths={'tools/pinball_rs.py','tools/qa_storage.py','tools/qa_legacy_storage.py','tools/qa_love_storage.py',
  'tools/qa_preserved.py','tools/qa_release_storage.py','tools/qa_build_storage.py',
  'tools/pinball-rs-native/CMakeLists.txt','tools/pinball-rs-native/bridge.cpp',
  'tools/pinball-rs-native/presentation.cpp','tools/pinball-rs-native/presentation.h',
  'tools/pinball-rs-native/runtime-fixes.patch'}
 for _,path in ipairs(paths)do
  local bytes=fs.read(path);if not bytes then return end
  local target='pinball-backend/'..path;fs.createDirectory(target:match('^(.*)/'))
  if not fs.write(target,bytes)then return end
 end
 cached=fs.getSaveDirectory()..'/pinball-backend';return cached
end
function B.python()
 local bundle=require('src.import.PokemonXYBackend').runtime()
 return os.getenv('ASCENDANT_PINBALL_PYTHON')or(bundle and bundle..'/python/bin/python3.12')or'python3'
end
return B
