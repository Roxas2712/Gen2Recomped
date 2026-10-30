-- Public TCG API contract, sandbox, lifecycle and online compatibility.
local M=require('src.tcg.Mods');local Json=require('src.link.Json')
local function hash(s)local n=0;for i=1,#s do n=(n*31+s:byte(i))%2147483647 end;return string.format('%064x',n)end
local base={id='sample',name='Sample',game='tcggbc',api=1,version='1.0.0',online='disabled',capabilities={'memory.read','memory.write','overlay'}}
local disk={['tcg-mods/enabled.json']='{"sample":true}',['tcg-mods/sample/manifest.json']=Json.encode(base),['tcg-mods/sample/main.lua']=[[
assert(io==nil and os==nil and ffi==nil and require==nil and love==nil and loadstring==nil)
assert(math.random==nil and string.dump==nil)
assert(api.assets.read('asset.txt')=='hello')
api.on('start',function()api.memory.write('eram',0,'S')end)
api.on('frame',function(info)
 assert(api.memory.read('eram',0,1)=='S')
 api.memory.write('wram',10,string.char(info.frame))
end)
api.on('draw',function()api.draw.rectangle(0,0,2,2);api.draw.text('TCG',1,1)end)
api.on('stop',function()api.log('closed')end)
]],['tcg-mods/sample/asset.txt']='hello'}
local fs={read=function(p)return disk[p]end,write=function(p,b)disk[p]=b;return true end,createDirectory=function()return true end}
function fs.getInfo(p)if disk[p]then return{type='file',size=#disk[p]}end end
function fs.getDirectoryItems(p)
 if p=='tcg-mods'then return{'sample','enabled.json'}elseif p=='tcg-mods/sample'then return{'main.lua','manifest.json','asset.txt'}end;return{}
end
local calls={};local host={modInfo=function()return{frame=1}end,modRead=function()return'S'end,modWrite=function(_,region,offset,data)calls[#calls+1]={region,offset,data};return true end}
local instance=M.new(host,false,{fs=fs,hash=hash});local signature=instance.signature
assert(#instance.mods==1);instance:emit('start');instance:emit('frame',{frame=7});assert(#calls==2 and calls[2][3]==string.char(7))
instance:emit('draw');assert(#instance.commands==2,'Overlays must enqueue draw commands')

assert(instance:close());assert(instance.host==nil and #instance.mods==0)
assert(not pcall(M.new,host,true,{fs=fs,hash=hash}),'Solo mods must be rejected online')
base.online='cosmetic';disk['tcg-mods/sample/manifest.json']=Json.encode(base)
assert(not pcall(M.new,host,true,{fs=fs,hash=hash}),'Writing mods cannot opt into online')
base.capabilities={'memory.read','overlay'};disk['tcg-mods/sample/manifest.json']=Json.encode(base)
disk['tcg-mods/sample/main.lua']="api.on('draw',function()api.draw.text('cosmetic',0,0)end)"
local cosmetic=M.new(host,true,{fs=fs,hash=hash});local first=cosmetic.signature;assert(first~=signature);assert(cosmetic:close())
disk['tcg-mods/sample/asset.txt']='changed'
local changed=M.new(host,true,{fs=fs,hash=hash});assert(changed.signature~=first,'All assets must enter the online mod fingerprint');assert(changed:close())
disk['tcg-mods/sample/main.lua']="api.assets.read('../other/secret')"
assert(not pcall(M.new,host,false,{fs=fs,hash=hash}),'Mods cannot read outside their frozen assets')
disk['tcg-mods/sample/main.lua']="api.on('frame',function()while true do end end)"
local runaway=M.new(host,false,{fs=fs,hash=hash});assert(not pcall(runaway.emit,runaway,'frame',{}),'Runaway callbacks must hit an instruction limit');runaway:close()
assert(M.toggle('sample',fs)==false);assert(#M.new(host,false,{fs=fs,hash=hash}).mods==0,'Disabled mods must not execute')
print('TCG API 1: lifecycle, memory capabilities, overlays, sandbox, asset identity, online restrictions and instruction limit: PASS')
