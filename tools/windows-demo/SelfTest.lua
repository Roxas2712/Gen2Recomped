-- Optional user diagnostics: isolated QA profile, public policy only.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
function M.install()
 local realLove=love
 local report={schema=1,passed=false,platform=love.system.getOS(),checks={},scope='Native HTTPS plus fixture save/profile regressions. No player account upload or native cartridge gameplay.'}
 local function check(ok,name)assert(ok,name);report.checks[#report.checks+1]={name=name,passed=true}end
 local function finish(ok,why)
  love=realLove;report.passed=ok;report.error=why
  local bytes=require('src.link.Json').encode(report)
  assert(love.filesystem.write('cloud-selftest.json',bytes))
  print('CLOUD_SELFTEST '..bytes)
  print('Report: '..love.filesystem.getSaveDirectory()..'/cloud-selftest.json')
  love.event.quit(ok and 0 or 1)
 end
 local task,started
 function love.load()
  local ok,why=pcall(function()
   assert(love.filesystem.getIdentity():match('^oasc%-windows%-cloud%-qa%-'))
   check(require('https').request~=nil,'Bundled native HTTPS is present')
   check(require('src.cloud.Http').available(),'Account transport is available without external curl')
   report.nativeRuntime=require('tools.windows-demo.NativeSelfTest').run(check)
   local fs=love.filesystem;local base='profile-fixtures-Ömega'
   assert(fs.createDirectory(base..'/Gen2Recomp/saves/red'))
   assert(fs.createDirectory(base..'/Gen2Recomp/data/generated'))
   assert(fs.write(base..'/Gen2Recomp/options.lua','SYNTHETIC ORIGINAL OPTIONS'))
   assert(fs.write(base..'/Gen2Recomp/saves/red/slot1.lua','SYNTHETIC ORIGINAL SAVE'))
   assert(fs.write(base..'/Gen2Recomp/data/generated/cache.lua','SYNTHETIC IMPORT MARKER'))
   local P=require('tools.windows-demo.Profile')
   local rows=assert(P.scan(fs,fs.getSaveDirectory()..'/'..base))
   check(#rows==1 and rows[1].identity=='Gen2Recomp'and rows[1].imports and rows[1].progress,'Native Unicode profile discovery finds imports and saves')
   check(fs.read(base..'/Gen2Recomp/options.lua')=='SYNTHETIC ORIGINAL OPTIONS'and fs.read(base..'/Gen2Recomp/saves/red/slot1.lua')=='SYNTHETIC ORIGINAL SAVE'and fs.read(base..'/Gen2Recomp/data/generated/cache.lua')=='SYNTHETIC IMPORT MARKER','Native profile discovery preserves original fixture bytes')
   task=assert(require('src.cloud.Task').new(function()
    local status,body=require('src.cloud.Http').request('GET','https://pokexpert.de/api/cloud/v1/auth/policy',{sensitive=true})
    local doc=status==200 and require('src.link.Json').decode(body)
    assert(doc and doc.version,'Public policy HTTPS failed: '..tostring(status))
    return true
   end));started=love.timer.getTime()
  end)
  if not ok then finish(false,tostring(why))end
 end
 function love.update()
  if not task then return end
  local result=task:poll();if not result and love.timer.getTime()-started<65 then return end
  task=nil
  local ok,why=pcall(function()
   check(result and result.kind=='done'and result.first,'Real background HTTPS policy request')
   for _,name in ipairs{'windows_demo_profile','cloud_outbox','cloud_setup','cloud_save_feedback'}do
    local original={};for key,value in pairs(package.loaded)do original[key]=value end
    for key in pairs(package.loaded)do if key:match('^src%.')or key=='tests.love_stub'then package.loaded[key]=nil end end
    local ran,problem=pcall(function()assert(love.filesystem.load('tests/engine/fixture-'..name..'.lua'))()end)
    love=realLove
    for key in pairs(package.loaded)do if not original[key]then package.loaded[key]=nil end end
    for key,value in pairs(original)do package.loaded[key]=value end
    check(ran,'Save/profile fixture regression: '..name..(not ran and(' · '..tostring(problem))or''))
   end
  end)
  finish(ok,not ok and tostring(why)or nil)
 end
end
return M
