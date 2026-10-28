-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Qualify options, PC history and automatic ending from one frozen ROM import.
return function(game)
 local version=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
 local J=require('src.link.Json');local stages={}
 if version=='emerald'or version=='firered'or version=='leafgreen'then
  stages[#stages+1]={'options','tests/gba_native_options_driver.lua'}
 end
 stages[#stages+1]={'hallPc','tests/gba_hall_pc_native_driver.lua'}
 local ending=version=='emerald'and'emerald'or(version=='ruby'or version=='sapphire')and'rs'or'frlg'
 stages[#stages+1]={'ending','tests/'..ending..'_ending_save_native_driver.lua'}
 local report={status='running',edition=version,preparedFixture=true,continuousStory=false,stages={},captures={}}
 local function write(path,bytes)local f=assert(io.open(path,'w'));f:write(bytes);f:close()end
 for _,stage in ipairs(stages)do
  local actualQuit=love.event.quit;local exitCode
  love.event.quit=function(code)exitCode=code or 0 end
  local ok,why=pcall(assert(love.filesystem.load(stage[2]))(),game)
  love.event.quit=actualQuit
  assert(ok,'drivererror: '..stage[1]..': '..tostring(why))
  assert(exitCode==0,'drivererror: '..stage[1]..' did not finish successfully')
  local f=assert(io.open(out..'/result.json','r'));local raw=f:read('*a');f:close()
  local child=assert(J.decode(raw));assert(child.status=='pass'and child.edition==version)
  report.stages[stage[1]]=child
  write(out..'/'..stage[1]..'-result.json',raw)
  for _,name in ipairs(child.captures)do report.captures[#report.captures+1]=name end
  write(out..'/result.json',J.encode(report))
 end
 report.status='pass';report.drawPreservesSaveRng=true
 write(out..'/result.json',J.encode(report));print('PASS_NATIVE_GBA_HALL_INTEGRATION');love.event.quit(0)
end
