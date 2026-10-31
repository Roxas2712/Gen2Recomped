-- Isolated native UI evidence; no real cloud account or ROM replacement.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
return function()
 assert(love.filesystem.getIdentity():match('^oasc%-')and love.filesystem.getIdentity():find('qa',1,true))
 local G=require('src.core.Game');local J=require('src.link.Json');local out=os.getenv('IMPORT_QA_OUT');local case=os.getenv('MOD_FEATURE_CASE')
 local report={passed=false,checks={}};local function wait(n)for _=1,n do coroutine.yield()end end
 local function write()local f=assert(io.open(out..'/'..case..'.json','wb'));f:write(J.encode(report));f:close()end
 local function capture(name)G.capturePath=out..'/'..name..'.png';for _=1,180 do if not G.capturePath then return end;wait(1)end;error('capture timeout')end
 love.errorhandler=function(e)report.fatal=tostring(e);write();return function()return 1 end end
 local ok,why=pcall(function()
  require('src.translation.Service').setLauncher({launcherLanguage='de'})
  local RI=require('src.import.RomImporter');local ui=RI.new(function()end);ui.section='games';ui.gamesView='consoles';ui.tab='red';ui.pageScroll=0
  local Sync=require('src.storage.SyncStatus');Sync.result(nil,'Your cloud storage is full. Free some cloud space, then retry.')
  local canvas=love.graphics.newCanvas(love.graphics.getDimensions())
  love.draw=function()
   love.graphics.push('all');love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(0,0,0,1);ui:draw();love.graphics.setCanvas();love.graphics.setColor(1,1,1);love.graphics.draw(canvas);love.graphics.pop()
   if G.capturePath then local path=G.capturePath;G.capturePath=nil;love.graphics.captureScreenshot(function(image)local f=assert(io.open(path,'wb'));f:write(image:encode('png'):getString());f:close()end)end
  end
  G.stack:push(ui);wait(90);capture('cloud-error')
  local retried=false;local original=ui._settingsAction;ui._settingsAction=function(self,row,...)if row.action=='storageRetry'then retried=true;return end;return original(self,row,...)end
  local r=assert(ui._cloudRetryRect,'inline retry is missing');ui:_sbMousepressed(r.x+r.width/2,r.y+r.height/2);assert(retried)
  report.checks[#report.checks+1]={name='Native cloud error banner exposes its reason and an inline retry',passed=true}
  local M=require('src.import.ImportReview');local resumed=false;local ready=ui.ready.red
  assert(M.request(ui,'red',function()resumed=true end,true));assert(not M.accept(ui,ui._modConfirm))
  wait(30);capture('reimport-review')
  ui:keypressed('escape');assert(not resumed and not ui._modConfirm and ui.ready.red==ready)
  report.checks[#report.checks+1]={name='Native re-import review blocks accidental confirmation; Escape preserves Play',passed=true}
  M.request(ui,'red',function()resumed=true end,true)
  while love.timer.getTime()-ui._modConfirm.opened<.5 do wait(1)end
  wait(10);r=assert(ui._modConfirmYes);ui:mousepressed(r.x+r.width/2,r.y+r.height/2,1);assert(resumed and not ui._modConfirm)
  report.checks[#report.checks+1]={name='Explicit confirmation reaches only the reviewed replacement callback',passed=true}
  report.passed=true
 end)
 if not ok then report.fatal=tostring(why)end;write();love.event.quit(report.passed and 0 or 1)
end
