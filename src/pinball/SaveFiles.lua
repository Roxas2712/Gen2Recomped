-- Native Pinball SRAM import/export. Contributions by Roxas2712.
local M={}
local function windows()return love.system and love.system.getOS()=='Windows'end
local function read(path)if not path then return end;if windows()then return require('src.core.NativeFile').read(path)end;local f=io.open(path,'rb');if not f then return end;local b=f:read('*a');f:close();return b end
local function write(path,data)
 if windows()then return require('src.core.NativeFile').atomicWrite(path,data)end
 local f,why=io.open(path..'.pending','wb');if not f then return nil,why end
 local ok,err=f:write(data);local closed=f:close();if not ok or not closed then return nil,err or 'Could not write save.'end
 return os.rename(path..'.pending',path)
end
function M.path(session)return session.player and session.player..'/solo-'..(session.locale or 'en')..'-1.sav'end
function M.exists(session)
 if windows()then local stream,size=require('src.core.NativeFile').openRead(M.path(session));if stream then stream:close()end;return stream~=nil and size==32768 end
 local path=M.path(session);local f=path and io.open(path,'rb');if not f then return false end
 local size=f:seek('end');f:close();return size==32768
end
function M.import(session,path)
 if windows()then
  local data=read(path);if not data or#data~=32768 then return nil,'Pinball saves must be exactly 32768 bytes.'end
  local target=M.path(session);local previous=read(target)
  if previous then
   local backup=target..'.before-import-'..os.time();local n=0
   while read(backup..'.sav')do n=n+1;backup=target..'.before-import-'..os.time()..'-'..n end
   local ok,why=write(backup..'.sav',previous);if not ok then return nil,why end
  end
  return write(target,data)
 end
 local f=io.open(path,'rb');if not f then return nil,'Pinball saves must be exactly 32768 bytes.'end
 local size=f:seek('end');if size~=32768 then f:close();return nil,'Pinball saves must be exactly 32768 bytes.'end
 f:seek('set',0);local data=f:read(32768);f:close()
 if not data or #data~=32768 then return nil,'Pinball saves must be exactly 32768 bytes.'end
 local target=M.path(session);local previous=read(target)
 if previous then
  local backup=target..'.before-import-'..os.time();local n=0
  while read(backup..'.sav')do n=n+1;backup=target..'.before-import-'..os.time()..'-'..n end
  local ok,why=write(backup..'.sav',previous);if not ok then return nil,why end
 end
 return write(target,data)
end
function M.export(session)
 local data=read(M.path(session));if not data or #data~=32768 then return nil,'No Pinball save exists for this language yet.'end
 love.filesystem.createDirectory('exports')
 local relative='exports/pinball-'..(session.locale or 'en')..'-'..os.time()..'.sav'
 local ok,why=love.filesystem.write(relative,data)
 return ok and love.filesystem.getSaveDirectory()..'/'..relative or nil,why
end
return M
