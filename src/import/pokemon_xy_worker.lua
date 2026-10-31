-- Fork integration by Roxas2712. Keep host waits off the render thread.
require('love.system');require('love.filesystem');require('love.thread')
local Json=require('src.link.Json')
local job=Json.decode(...)
local channel=love.thread.getChannel('pokemon.xy.result')
local Shell=require('src.core.HostShell')
local function command(action,extras)
 local args={job.python,'-X','utf8','-B','-E','-s',job.root..'/tools/pokemon_x_backend.py',action,'--edition',job.edition,'--root',job.root,'--worker-protocol'}
 if job.runtime_root then args[#args+1]='--runtime-root';args[#args+1]=job.runtime_root end
 for _,a in ipairs(extras or {}) do args[#args+1]=a end
 if job.qa_profile and (action=='prepare' or action=='import' or action=='build') then args[#args+1]='--qa-profile';args[#args+1]=job.qa_profile end
 return args
end
local function spawn(action,extras)return require('src.translation.DesktopProcess').argv(command(action,extras),true)end
local function state()
 local status=assert(spawn('status'))
 local data;local terminal
 for line in status:lines()do
  if line:sub(1,1)=='{' then
   local ok,row=pcall(Json.decode,line)
   if ok and type(row)=='table' then
    if row.backend_result~=nil then terminal=row.backend_result else data=row end
   end
  end
 end
 status:close()
 assert(terminal==0 and type(data)=='table','Invalid library response')
 return data
end
local ok,errorText=pcall(function()
 local pipe=assert(spawn(job.action,job.args),'Backend could not start')
 local tail='';local prepared;local edition;local terminal
 for line in pipe:lines() do
  if line:sub(1,1)=='{' then
   local ok,row=pcall(Json.decode,line)
   if ok and type(row)=='table' then
    if row.native_session then prepared=row end
    if row.imported_edition then
     edition=row.imported_edition
     channel:push(Json.encode{progress='Preparing your game. The first import can take several minutes.',edition=edition,data=row.library})
    end
    if row.progress then channel:push(Json.encode{progress=row.progress})end
    if row.backend_result~=nil then terminal=row.backend_result end
   end
  else tail=(tail..line..'\n'):sub(-5000) end
  local done,total=line:match('^compiled (%d+) of (%d+)$')
  if done and tonumber(total)<=20000 and tonumber(done)<=tonumber(total) then
   channel:push(Json.encode{progress='Compiling game · %d / %d',completed=tonumber(done),total=tonumber(total)})
  end
 end
 local success,why,code=pipe:close()
 -- LuaJIT's popen close cannot reliably report a failed child on every host.
 -- Require the explicit final protocol record, including for interrupted jobs.
 if not success or terminal~=0 then
  local ok,data=pcall(state)
  channel:push(Json.encode{ok=false,error=tail~='' and tail or ('Backend exit '..tostring(terminal or code or why)),data=ok and data or nil})
  return
 end
 local data=state()
 channel:push(Json.encode{ok=true,data=data,session=prepared and prepared.native_session,mode=job.mode,edition=edition})
end)
if not ok then channel:push(Json.encode{ok=false,error=tostring(errorText)}) end
