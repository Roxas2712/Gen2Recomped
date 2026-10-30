require('love.thread')
local Json=require('src.link.Json');local Shell=require('src.core.HostShell')
local job,channel=...
local ok,why=pcall(function()
 local args={job.python,'-B','-E','-s',job.root..'/tools/tcg_gbc.py','prepare','--rom',job.path}
 for _,name in ipairs{'cmake','ninja','runtime','min-free-gib'}do if job[name]then args[#args+1]='--'..name;args[#args+1]=tostring(job[name])end end
 for i,value in ipairs(args)do args[i]=Shell.quote(value)end
 local pipe=assert(Shell.popen(table.concat(args,' ')..' 2>&1','r'))
 local data,tail=nil,''
 for line in pipe:lines()do
  if line:sub(1,1)=='{'then local parsed,row=pcall(Json.decode,line);if parsed and type(row)=='table'and row.ready then data=row end
  else tail=(tail..line..'\n'):sub(-1800);channel:push(Json.encode{progress=line})end
 end
 local done=pipe:close()
 channel:push(Json.encode{ok=data~=nil and done~=false,data=data,error=not data and tail or nil})
end)
if not ok then channel:push(Json.encode{ok=false,error=tostring(why)})end
