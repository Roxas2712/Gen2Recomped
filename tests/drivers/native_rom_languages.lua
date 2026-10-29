-- Real imported-data/native renderer acceptance. No normal game save is written.
local function wait(n) for _=1,n do coroutine.yield() end end
return function(game)
 -- Scripted acceptance owns input while its native frames are being checked.
 -- Physical typing in another chat must not open Reset profile mid-startup.
 for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
 if love.keyboard then love.keyboard.isDown=function()return false end end
 local ok,why=xpcall(function()
  local V=require('src.core.GameVersion');local version=V.get()
  local S=require('src.core.SaveSerializer')
  local e=assert(game.mods.exports.german_rom_source,'Language mod missing')
  assert(e.localizationBackend=='native-rom-language-v1','Separate host adapter was selected')
  local api=assert(game.mods.apis.german_rom_source)
  print('NATIVE_LANGUAGE_STARTUP',version,require('src.link.Json').encode(e.startup and e.startup.choices or{}),api.imports:info(version..'_de')and'import present'or'import absent')
  assert(e.status=='active' and e.language=='de',e.session and e.session.error or e.status)
  if e.startup and e.startup.open then
   if e.startup.stage=='reset'then assert(e.startup.back())end
   local accepted,reason=e.startup.choose('de')
   assert(accepted,'Native first-run language confirmation failed: '..tostring(reason)..' / '..tostring(e.startup.stage)..' / '..tostring(e.startup.noticeKey))
  end
  assert(not e.startup.open,'Startup overlay still intercepts native gameplay')
  local input=assert(api.imports:info(version..'_de'))
  local bytes=assert(api.imports:read(version..'_de',0,input.size))
  assert(e.session:importBytes(bytes),'Native launcher import rejected the exact language ROM')
  assert(api.imports:info(version..'_de').sha1==input.sha1,'Native reimport changed the source identity')
  assert(not api:info('fork/main.lua'),'QA mod still ships the separate conversion backend')
  assert(not api:info('hosts/gen2/main.lua'),'QA mod still ships the legacy Gen2 conversion backend')
  local mon
  for _,row in pairs(game.data.pokemon) do if row.name=='BISASAM' then mon=row;break end end
  assert(mon,'Native species names were not localized')
  assert(e.coverage.applied.dialogue>(V.generation()==3 and 300 or 1000),'Native dialogue coverage missing')
  local cache=V.cachePrefix()..'data/generated/'
  for _,registry in ipairs({'pokemon','moves','items','trainers'}) do
   local base=assert(loadstring(assert(love.filesystem.read(cache..registry..'.lua'))))()
   for id,row in pairs(base) do if type(row)=='table' and game.data[registry][id] then
    for _,field in ipairs({'baseStats','types','type','catchRate','baseExp','growthRate','learnset','evolutions','tmhm','eggMoves','power','accuracy','pp','effect','effectChance','price','heldEffect','heldParam','parties'}) do
     assert(S.encode(row[field] or{})==S.encode(game.data[registry][id][field] or{}),'Language changed mechanics: '..registry..'.'..tostring(id)..'.'..field)
    end
   end end
  end
  local function progress() return S.encode(game.save) end
  -- The driver's first frame can still be in the native opening movie.
  while game.stack:top() do game.stack:pop() end
  game.stack:push(game:makeTitleState())
  local before=progress();local translated=S.encode(game.data.text)
  assert(e.session:canSwitch(),'Title not eligible for language change')
  assert(e.session:request('en'));e.session:update()
  assert(e.language=='en' and progress()==before,'English switch lost live progress')
  local digest=love.data.encode('string','hex',love.data.hash('sha256',S.encode(game.data.text)))
  assert(digest==e.baseTextSha256,'English did not restore the exact native text baseline')
  assert(e.session:request('de'));e.session:update()
  assert(e.language=='de' and S.encode(game.data.text)==translated and progress()==before,'Warm language switch drifted')
  local Strings=require('src.core.Strings');local load=Strings.load
  Strings.load=function(...) Strings.load=load;error('intentional native language rollback check') end
  assert(e.session:request('en'));e.session:update()
  assert(e.language=='de' and e.session.error and progress()==before and S.encode(game.data.text)==translated,'Native failed-switch rollback lost state')
  e.session:close()
  assert(not e.session:importBytes('invalid cartridge'),'Invalid cartridge was accepted')
  assert(e.language=='de' and progress()==before,'Rejected input changed the active session')
  e.session:close()
  wait(3);love.graphics.captureScreenshot('native-language-title.png');wait(2)
  while game.stack:top() do game.stack:pop() end
  local world=require('src.world.OverworldController')
  local g=V.generation()
  local map=g==2 and 'CHERRYGROVE_POKECENTER1_F' or game.save.player.map
  game.stack:push(world,map,g==2 and 3 or game.save.player.x,g==2 and 3 or game.save.player.y,'up')
  for _=1,240 do if e.session:canSwitch() then break end;wait(1) end
  assert(e.session:canSwitch(),'Native overworld did not settle: '..tostring(game.stack:top()and game.stack:top().screenId)..' / '..tostring(world.player.inputLocked)..' / '..tostring(world.script and world.script.isRunning and world.script:isRunning()))
  before=progress();local mapId,x,y=world.map.id,world.player.x,world.player.y
  assert(e.session:request('en'));e.session:update()
  assert(e.language=='en' and progress()==before,'Overworld switch changed save data')
  assert(e.session:request('de'));e.session:update()
  assert(e.language=='de' and progress()==before and world.map.id==mapId and world.player.x==x and world.player.y==y,'Overworld handoff lost position')
  world.player.moving=true;assert(not e.session:request('en'),'Moving player could change language');world.player.moving=false
  if g==2 then
   local Box=require('src.render.TextBox');local create=Box.new;local spoken={}
   Box.new=function(owner,text,...) spoken[#spoken+1]=text;return create(owner,text,...) end
   world:interact()
   for _=1,180 do if #spoken>0 then break end;wait(1) end
   Box.new=create
   local text=table.concat(spoken,'\n')
   assert(text:find('Willkommen',1,true) and text:find('CENTER',1,true),'Actual nurse script was not localized: '..text)
   print('NATIVE_LANGUAGE_NURSE',version,text)
  end
  wait(8);love.graphics.captureScreenshot('native-language-world.png');wait(3)
  print('NATIVE_ROM_LANGUAGE_OK',version,require('src.link.Json').encode(e.coverage.applied))
 end,debug.traceback)
 if not ok then print('NATIVE_ROM_LANGUAGE_FAILED',why) end
 love.event.quit(ok and 0 or 1)
end
