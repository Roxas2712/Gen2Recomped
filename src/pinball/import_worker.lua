require('love.thread')
local Json=require('src.link.Json');local Shell=require('src.core.HostShell')
local job,channel=...
local ok,why=pcall(function()
 local args={job.python,'-B','-E','-s',job.root..'/tools/pinball_rs.py','import','--rom',job.path,'--worker-protocol'}
 for _,name in ipairs{'cmake','ninja'}do if job[name]then args[#args+1]='--'..name;args[#args+1]=job[name]end end
 for i,value in ipairs(args)do args[i]=Shell.quote(value)end
 local pipe=assert(Shell.popen(table.concat(args,' ')..' 2>&1','r'))
 local terminal,data,tail=nil,nil,''
 for line in pipe:lines()do
  if line:sub(1,1)=='{'then
   local parsed,row=pcall(Json.decode,line)
   if parsed and type(row)=='table'then
    if row.backend_result~=nil then terminal=row.backend_result else data=row end
   end
  else tail=(tail..line..'\n'):sub(-1500);channel:push(Json.encode{progress='Preparing your Pinball game …'})end
 end
 pipe:close()
 channel:push(Json.encode{ok=terminal==0,data=data,error=terminal~=0 and tail or nil})
end)
if not ok then channel:push(Json.encode{ok=false,error=tostring(why)})end
