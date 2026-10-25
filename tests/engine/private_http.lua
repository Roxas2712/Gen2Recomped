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
print('Private HTTP: '..n..' checks passed')
