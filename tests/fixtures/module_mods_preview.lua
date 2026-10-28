-- Synthetic UI fixture: no account, download, ROM or real save is used.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local ui,frame,scrolled= nil,0,false
function love.load()
 require('src.core.SaveData').otherLocations=function()return{}end
 package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return'qa-layout'end}
 package.loaded['src.cloud.Task']={new=function()return nil,'Networking disabled in layout fixture'end}
 require('src.core.Version').engine='0.8.56'
 if os.getenv('MODULE_MODS_ARCHIVES')then
  local f=assert(io.open(os.getenv('MODULE_MODS_ARCHIVES'),'rb'));local config=require('src.link.Json').decode(f:read('*a'));f:close()
  local count=require('tests.fixtures.module_mods_archives')(config)
  f=assert(io.open(config.result,'wb'));f:write(require('src.link.Json').encode({passed=true,checks=count,scope='Real LÖVE ZIP mounting and isolated QA filesystem; no live download'}));f:close()
 end
 local RI=require('src.import.RomImporter')
 ui=RI.new(function()error('Layout fixture cannot start games')end,{launcher=true})
 ui._launcherSequence=nil;ui._setupPending=nil;ui._setupOverlay=nil
 ui._sbDrawBackdrop=function()end;ui._sbBackdropWant=function()end
 ui._newsPending=false;ui._news={items={}};ui:_sbOpenGame('crystal')
 ui.ready.crystal=true;ui.modsLoaded=true;ui.findLoaded=true
 ui._ensureMods=function()end;ui._ensureFind=function()end;ui._findThumb=function()end
 ui.mods={{id='qa-local',name='QA · Crystal Quality of Life',version='1.2.0',games={'crystal'},enabled=true},
  {id='qa-off',name='QA · Optional Music Pack',version='1.0.0',games={'gen2'},enabled=false}}
 ui.findIndex={mods={}}
 for i,title in ipairs{'QA · Crystal Visual Pack','QA · Johto Adventures','QA · Battle Interface'}do
  ui.findIndex.mods[i]={id='qa-mod-'..i,title=title,summary='Synthetic preview · no download',games={'gen2'},api=3,game_version='>=0.8.0',
   downloadURL='https://example.invalid/qa.zip',categories={({'Grafik','Inhalte','Oberfläche'})[i]}}
 end
 require('src.translation.Service').launcherActive=true
 require('src.translation.Service').launcherTarget='de'
 ui:_settings().launcherLanguage='de'
end
function love.update()frame=frame+1 end
function love.draw()
 ui:draw()
 if frame>=2 and not scrolled then
  assert(ui._gameModsTop,'The actual module page must contain the mod section')
  ui.pageScroll=math.max(0,ui.pageScroll+ui._gameModsTop-240+(tonumber(os.getenv('MODULE_MODS_SCROLL_EXTRA'))or 0));scrolled=true
 end
 if frame>=5 then
  frame=-100000
  love.graphics.captureScreenshot(function(data)
   local path=assert(os.getenv('MODULE_MODS_CAPTURE'))
   local f=assert(io.open(path,'wb'));f:write(data:encode('png'):getString());f:close()
   print('Module mods: actual launcher renderer captured; synthetic catalogue, networking disabled')
   love.event.quit(0)
  end)
 end
end
function love.errorhandler(err)
 print(tostring(err)..'\n'..debug.traceback())
 return function()return 1 end
end
