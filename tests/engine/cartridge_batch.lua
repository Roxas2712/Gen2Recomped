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
local member=true
package.loaded['src.import.CartridgeDownload']={member=function()return member end,start=function(v,confirmed)
 assert(confirmed);requests=requests+1
 return {poll=function() return {kind='done',bytes=v} end,cancel=function()cancelled=cancelled+1 end}
end}
local ui={_cartBatch={},_cartImageBytes=function(_,bytes) return {bytes='png-'..bytes} end}
local n=0;local function check(v,m) assert(v,m);n=n+1 end
B.start(ui,false);check(not ui._cartBatch.running and requests==0,'one explicit confirmation is required for the entire collection')
local queue,skipped,bytes=B.plan(options.launcherCartDesigns,function() return true end)
check(#queue==17 and skipped==2 and bytes>0,'saved custom artwork and custom shells are protected by the initial plan')
local queued=','..table.concat(queue,',')..','
check(queued:find(',x,',1,true)and queued:find(',y,',1,true)and queued:find(',pinballrs,',1,true),'the original-image batch includes 3DS and Pinball without a native installation')
B.start(ui,true)
for i=1,40 do B.tick(ui) end
check(ui._cartBatch.done==17 and not ui._cartBatch.running and applied==17,'the complete batch applies images without per-cartridge saves or confirmations')
check(options.launcherCartDesigns.red.art=='custom.png' and options.launcherCartDesigns.blue.shell[1]==1,'custom designs survive the batch unchanged')
check(options.launcherCartDesigns.crystal.artMode=='cartridge' and options.launcherCartDesigns.crystal.originalSha256==Source.get('crystal').sha256,'applied images retain their original source fingerprint and whole-cartridge mode')
B.start(ui,true);B.tick(ui)
check(ui._cartBatch.done==0 and requests==17,'a repeated batch skips every already applied image')
options.launcherCartDesigns.silver=nil;B.start(ui,true);B.tick(ui);B.cancel(ui)
check(cancelled==1 and not ui._cartBatch.running,'cancelling stops the active download and keeps completed images')
B.start(ui,true);B.tick(ui);owner='17';B.tick(ui)
check(cancelled==2 and not ui._cartBatch.running and not options.launcherCartDesigns.silver,'changing account cancels rather than writing into the new profile')
print('Cartridge batch: '..n..' checks passed')

member=false;ui.launcher=true;ui._cartBatch={}
local before=requests;B.start(ui,true);check(not ui._cartBatch.running and requests==before,'a guest cannot start even a confirmed artwork batch')
check(B.setAutomatic(ui,true),'automatic preference can be saved before registration')
B.auto(ui);check(not ui._cartBatch.running and requests==before,'saved automatic downloads wait for a member login')
member=true;B.auto(ui);check(ui._cartBatch.running,'a confirmed member can resume the saved automatic choice')
for i=1,8 do B.tick(ui)end
local once=requests;B.auto(ui);check(requests==once,'completed automation does not loop every frame')
options.launcherCartDesigns.silver=nil;ui._cartAutoChecked=nil;B.auto(ui);B.tick(ui);B.cancel(ui);B.auto(ui)
check(not ui._cartBatch.running,'stop keeps automatic downloads paused for this launcher session')
check(B.setAutomatic(ui,false)and not options.launcherOriginalCartridges,'opt-out persists without deleting existing images')
print('Member artwork automation: '..n..' checks passed')
local versions=require('src.core.GameVersion');local originalOrder=versions.ORDER;local originalSource=Source.get
versions.ORDER={};for _,v in ipairs(originalOrder)do versions.ORDER[#versions.ORDER+1]=v end
versions.ORDER[#versions.ORDER+1]='futureedition'
Source.get=function(v)if v=='futureedition'then return {sha256=string.rep('f',64),bytes=1234}end;return originalSource(v)end
package.loaded['src.import.CartridgeBatch']=nil;local nextBuild=require('src.import.CartridgeBatch')
check(table.concat(nextBuild.ORDER,','):find('futureedition',1,true),'a new supported edition is discovered from the edition/source catalogue')
ui._cartBatch=nil;ui._cartAutoChecked=nil;ui._cartAutoPaused=nil;nextBuild.setAutomatic(ui,true);nextBuild.auto(ui)
for i=1,12 do nextBuild.tick(ui)end
check(options.launcherCartDesigns.futureedition and options.launcherCartDesigns.futureedition.originalSha256==string.rep('f',64),'the remembered member opt-in automatically loads an added edition')
versions.ORDER=originalOrder;Source.get=originalSource
print('Future cartridge catalogue: '..n..' checks passed')
