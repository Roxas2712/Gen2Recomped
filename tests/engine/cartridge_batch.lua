package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local B=require('src.import.CartridgeBatch')
local Source=require('src.import.CartridgeSources')
local options={launcherCartDesigns={red={art='custom.png'},blue={shell={1,2,3}}}}
local files={};local requests,applied,cancelled=0,0,0
package.loaded['src.core.SaveData']={loadOptions=function() return options end,saveOptions=function(o) options=o;applied=applied+1;return true end}
package.loaded['src.import.CartridgeBatch']=nil;B=require('src.import.CartridgeBatch')
local owner=nil;package.loaded['src.storage.AccountStorage']={scope=function() return owner end}
love.filesystem.getInfo=function(p) return files[p] and {type='file'} end
love.filesystem.write=function(p,b) files[p]=b;return true end
package.loaded['src.import.CartridgeDownload']={start=function(v,confirmed)
 assert(confirmed);requests=requests+1
 return {poll=function() return {kind='done',bytes=v} end,cancel=function()cancelled=cancelled+1 end}
end}
local ui={_cartBatch={},_cartImageBytes=function(_,bytes) return {bytes='png-'..bytes} end}
local n=0;local function check(v,m) assert(v,m);n=n+1 end
B.start(ui,false);check(not ui._cartBatch.running and requests==0,'one explicit confirmation is required for the entire collection')
local queue,skipped,bytes=B.plan(options.launcherCartDesigns,function() return true end)
check(#queue==14 and skipped==2 and bytes>0,'saved custom artwork and custom shells are protected by the initial plan')
B.start(ui,true)
for i=1,40 do B.tick(ui) end
check(ui._cartBatch.done==14 and not ui._cartBatch.running and applied==14,'the complete batch applies images without per-cartridge saves or confirmations')
check(options.launcherCartDesigns.red.art=='custom.png' and options.launcherCartDesigns.blue.shell[1]==1,'custom designs survive the batch unchanged')
check(options.launcherCartDesigns.crystal.artMode=='cartridge' and options.launcherCartDesigns.crystal.originalSha256==Source.get('crystal').sha256,'applied images retain their original source fingerprint and whole-cartridge mode')
B.start(ui,true);B.tick(ui)
check(ui._cartBatch.done==0 and requests==14,'a repeated batch skips every already applied image')
options.launcherCartDesigns.silver=nil;B.start(ui,true);B.tick(ui);B.cancel(ui)
check(cancelled==1 and not ui._cartBatch.running,'cancelling stops the active download and keeps completed images')
B.start(ui,true);B.tick(ui);owner='17';B.tick(ui)
check(cancelled==2 and not ui._cartBatch.running and not options.launcherCartDesigns.silver,'changing account cancels rather than writing into the new profile')
print('Cartridge batch: '..n..' checks passed')
