-- Isolated native UI and real anonymous HTTPS worker; no user credentials.
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
  local RI=require('src.import.RomImporter');local ui=RI.new(function()end);ui:_sbGo('settings');ui._setupOverlay=nil
  local canvas=love.graphics.newCanvas(love.graphics.getDimensions())
  love.draw=function()
   love.graphics.push('all');love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(0,0,0,1);ui:draw();love.graphics.setCanvas();love.graphics.setColor(1,1,1);love.graphics.draw(canvas);love.graphics.pop()
   -- The account renderer intentionally targets the final window. Render it
   -- after the test canvas as the actual frame compositor does.
   require('src.import.AccountWorkspace').draw(ui)
   if G.capturePath then local path=G.capturePath;G.capturePath=nil;love.graphics.captureScreenshot(function(image)local f=assert(io.open(path,'wb'));f:write(image:encode('png'):getString());f:close()end)end
  end
  G.stack:push(ui)
  local rows={};ui:_sbCloudRows(function(r)rows[#rows+1]=r end)
  for _,r in ipairs(rows)do assert(not(r.row and(r.row.id=='cloudService'or r.row.id=='cloudFolder')),'provider setup leaked into simple cloud settings')end
  report.checks[#report.checks+1]={name='Default native settings need no provider keys or folders',passed=true}
  local originalService=ui._sbCloudService;ui._sbCloudService=function()return'folder'end
  rows={};ui:_sbCloudRows(function(r)rows[#rows+1]=r end)
  local folder=false;for _,r in ipairs(rows)do if r.row and r.row.id=='cloudFolder'then assert(r.row.values and r.row.labels);folder=true end end
  assert(folder);ui._sbCloudService=originalService
  report.checks[#report.checks+1]={name='Existing sync folders retain their advanced controls',passed=true}
  local W=require('src.import.AccountWorkspace');W.open(ui);local f=ui._accountOverlay
  if f.job then f.job:cancel();f.job=nil end
  f.mode='login';f.policy=nil;wait(15);capture('cloud-login')
  assert(f.cloudSync,'new login must recommend automatic account cloud')
  f.mode='cloud_setup';f.profileSources={'guest','local'};f.scroll=0;wait(15);capture('cloud-ownership')
  local choices={};for _,r in ipairs(f.rects)do choices[r.id]=true end
  assert(choices.cloudGuest and choices.cloudLocal and choices.cloudSeparate)
  W.close(ui)
  report.checks[#report.checks+1]={name='Native login and one-time progress ownership choices render',passed=true}
  assert(require('src.cloud.Http').available(),'No bundled cloud transport')
  local task=assert(require('src.cloud.Task').new(function()
   local status,body=require('src.cloud.Http').request('GET','https://pokexpert.de/api/cloud/v1/auth/policy',{sensitive=true})
   assert(status==200,'Anonymous policy status: '..tostring(status))
   local doc=J.decode(body);assert(type(doc)=='table'and doc.version,'Incomplete account policy')
   return true
  end))
  local started=love.timer.getTime();local result
  repeat result=task:poll();if not result then wait(1)end;assert(love.timer.getTime()-started<65,'Anonymous HTTPS worker timeout')until result
  assert(result.kind=='done'and result.first,result.error or result.second)
  report.checks[#report.checks+1]={name='Real native background HTTPS reaches public account policy',passed=true}
  report.passed=true
 end)
 if not ok then report.fatal=tostring(why)end;write();love.event.quit(report.passed and 0 or 1)
end
