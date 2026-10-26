package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
love.system={getOS=function() return 'OS X' end}
love.filesystem.getSaveDirectory=function() return '/private/fixture' end
local commands,configs,writes={},{},{}
local write=love.filesystem.write
love.filesystem.write=function(path,bytes) writes[#writes+1]=bytes;return write(path,bytes) end
local host=require('src.core.HostShell')
host.popen=function(command,mode)
  commands[#commands+1]=command;check(mode=='w','private curl opens only a writable stdin pipe')
  return {write=function(_,config) configs[#configs+1]=config end,close=function()
    local config=configs[#configs]
    local out=config:match('output = "/private/fixture/([^"\n]+)"')
    local status=command:match("'/private/fixture/(http_private_status_[^']+)'")
    write(out,'{"state":"email_code"}');write(status,'202')
  end}
end
local H=require('src.cloud.Http')
local password='fixture " quote \\ slash $() % !\nsecond line'
local code,body=H.request('POST','https://pokexpert.de/api/cloud/v1/auth/login',{sensitive=true,body=password,headers={Authorization='Bearer private-fixture'}})
check(code==202 and body:find('email_code',1,true),'private curl returns the response and status')
check(not commands[1]:find('fixture "',1,true) and not commands[1]:find('private-fixture',1,true),'passwords and bearer tokens never appear in shell arguments')
check(configs[1]:find('data-binary = "fixture \\" quote',1,true) and not configs[1]:find('\nsecond line',1,true),'quotes and line breaks remain inside one curl configuration value')
check(configs[1]:find('proto = "=https"',1,true) and not configs[1]:find('location',1,true),'private requests enforce HTTPS without following redirects')
check(#writes==0,'request credentials never enter the filesystem transport')
check(not H.request('POST','http://pokexpert.de/auth',{sensitive=true,body=password}),'plaintext HTTP refuses credentials')
check(not H.request('POST','https://pokexpert.de/auth',{sensitive=true,headers={Authorization='token\nother'}}),'injected headers are rejected before starting curl')
local second=assert(loadfile('src/cloud/Http.lua'))()
H.tmpNamespace='worker-1';second.tmpNamespace='worker-2'
local paths={};local results={}
local oldTime=os.time;os.time=function()return 1234 end
host.popen=function(command)
 local status=command:match("'/private/fixture/(http_private_status_[^']+)'")
 return {write=function(_,config)
   local out=config:match('output = "/private/fixture/([^"\n]+)"')
   check(not paths[out] and not paths[status],'concurrent workers own distinct response/status paths even in the same second')
   paths[out]=true;paths[status]=true
   results[#results+1]={out=out,status=status}
   if #results==1 then local c,b=second.request('GET','https://pokexpert.de/test',{sensitive=true});check(c==200 and b=='second','interleaved worker reads its own response') end
  end,
  close=function()local r=results[status:find('worker2',1,true) and 2 or 1];write(r.out,status:find('worker2',1,true) and 'second' or 'first');write(r.status,'200')end}
end
local c,b=H.request('GET','https://pokexpert.de/test',{sensitive=true})
check(c==200 and b=='first','first request survives an overlapping private HTTP request')
os.time=oldTime
print('Private HTTP: '..n..' checks passed')
