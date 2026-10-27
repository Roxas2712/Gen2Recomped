-- Fork integration by Roxas2712. Keep host waits off the render thread.
require('love.system');require('love.filesystem');require('love.thread')
local Json=require('src.link.Json')
local job=Json.decode(...)
local channel=love.thread.getChannel('pokemon.xy.result')
local Shell=require('src.core.HostShell')
local function command(action,extras)
 local args={job.python,job.root..'/tools/pokemon_x_backend.py',action,'--edition',job.edition,'--root',job.root}
 for _,a in ipairs(extras or {}) do args[#args+1]=a end
 if action=='prepare' and job.qa_profile then args[#args+1]='--qa-profile';args[#args+1]=job.qa_profile end
 for i,a in ipairs(args) do args[i]=Shell.quote(a) end
 return table.concat(args,' ')..' 2>&1'
end
local ok,errorText=pcall(function()
 local pipe=assert(Shell.popen(command(job.action,job.args),'r'),'Backend could not start')
 local tail='';local prepared;local edition
 for line in pipe:lines() do
  tail=(tail..line..'\n'):sub(-5000)
  if job.action=='prepare' and line:sub(1,1)=='{' then local ok,row=pcall(Json.decode,line);if ok and type(row)=='table' and row.native_session then prepared=row end end
  if job.action=='import' and line:sub(1,1)=='{' then local ok,row=pcall(Json.decode,line);if ok and type(row)=='table' then edition=row.imported_edition end end
 end
 local success,why,code=pipe:close()
 if not success then error(tail~='' and tail or ('Backend exit '..tostring(code or why))) end
 local status=assert(Shell.popen(command('status'),'r'))
 local text=status:read('*a');status:close()
 local data=Json.decode(text)
 assert(type(data)=='table','Invalid library response')
 channel:push(Json.encode{ok=true,data=data,session=prepared and prepared.native_session,mode=job.mode,edition=edition})
end)
if not ok then channel:push(Json.encode{ok=false,error=tostring(errorText)}) end
