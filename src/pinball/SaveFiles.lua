-- Native Pinball SRAM import/export. Contributions by Roxas2712.
local M={}
local function read(path)if not path then return end;local f=io.open(path,'rb');if not f then return end;local b=f:read('*a');f:close();return b end
local function write(path,data)
 local f,why=io.open(path..'.pending','wb');if not f then return nil,why end
 local ok,err=f:write(data);local closed=f:close();if not ok or not closed then return nil,err or 'Could not write save.'end
 return os.rename(path..'.pending',path)
end
function M.path(session)return session.player and session.player..'/solo-'..(session.locale or 'en')..'-1.sav'end
function M.exists(session)
 local path=M.path(session);local f=path and io.open(path,'rb');if not f then return false end
 local size=f:seek('end');f:close();return size==(session.sram_size or 32768)
end
function M.import(session,path)
 local f=io.open(path,'rb');if not f then return nil,'Pinball saves must be exactly '..(session.sram_size or 32768)..' bytes.'end
 local size=f:seek('end');if size~=(session.sram_size or 32768) then f:close();return nil,'Pinball saves must be exactly '..(session.sram_size or 32768)..' bytes.'end
 f:seek('set',0);local data=f:read(session.sram_size or 32768);f:close()
 if not data or #data~=(session.sram_size or 32768) then return nil,'Pinball saves must be exactly '..(session.sram_size or 32768)..' bytes.'end
 local target=M.path(session);local previous=read(target)
 if previous then
  local backup=target..'.before-import-'..os.time();local n=0
  while read(backup..'.sav')do n=n+1;backup=target..'.before-import-'..os.time()..'-'..n end
  local ok,why=write(backup..'.sav',previous);if not ok then return nil,why end
 end
 return write(target,data)
end
function M.export(session)
 local data=read(M.path(session));if not data or #data~=(session.sram_size or 32768) then return nil,'No Pinball save exists for this language yet.'end
 love.filesystem.createDirectory('exports')
 local relative='exports/'..(session.edition or 'pinballrs')..'-'..(session.locale or 'en')..'-'..os.time()..'.sav'
 local ok,why=love.filesystem.write(relative,data)
 return ok and love.filesystem.getSaveDirectory()..'/'..relative or nil,why
end
return M
