local function wait(n)for _=1,n do coroutine.yield()end end
return function(game)
 for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
 love.keyboard.isDown=function()return false end
 local ok,why=xpcall(function()
  local V=require('src.core.GameVersion');local version=V.get();local S=require('src.core.SaveSerializer')
  local e=assert(game.mods.exports.german_rom_source)
  assert(e.sessionBoot and e.localizationBackend=='native-rom-language-v1' and e.status=='active' and e.language=='pt-BR',e.session and e.session.error or e.status)
  assert(e.coverage.applied.dialogue>(V.generation()==3 and 300 or 1000),'Portuguese dialogue coverage missing')
  local N=require('src.translation.NativeLanguages');local state=N.describe(version,'pt-BR')
  assert(state.ready and state.automatic,'Prepared Portuguese source is not ready')
  local info=assert(game.mods.apis.german_rom_source.imports:info(state.patchRecipe.sourceId))
  assert(info.sha1==state.patchRecipe.targetSha1,'Generated image differs from the published language profile')
  for _,registry in ipairs({'pokemon','moves','items','trainers'})do
   local path=V.cachePrefix()..'data/generated/'..registry..'.lua'
   local baseline=assert(loadstring(assert(love.filesystem.read(path))))()
   for id,row in pairs(baseline)do if type(row)=='table' and game.data[registry][id] then
    for _,key in ipairs({'baseStats','types','type','catchRate','baseExp','growthRate','learnset','evolutions','tmhm','power','accuracy','pp','effect','price','parties'})do
     assert(S.encode(row[key] or{})==S.encode(game.data[registry][id][key] or{}),'Portuguese changed gameplay: '..registry..'.'..tostring(id)..'.'..key)
    end
   end end
  end
  while game.stack:top()do game.stack:pop()end
  game.stack:push(game:makeTitleState());wait(4)
  local before=S.encode(game.save);local text=S.encode(game.data.text)
  assert(e.session:request('en'));e.session:update()
  assert(e.language=='en'and S.encode(game.save)==before,'English switch changed progress')
  local digest=love.data.encode('string','hex',love.data.hash('string','sha256',S.encode(game.data.text)))
  assert(digest==e.baseTextSha256,'Original US text not restored')
  assert(e.session:request('pt-BR'));e.session:update()
  assert(e.language=='pt-BR'and S.encode(game.data.text)==text and S.encode(game.save)==before,'Portuguese warm switch drifted')
  local Strings=require('src.core.Strings');local load=Strings.load
  Strings.load=function(...)Strings.load=load;error('intentional Portuguese rollback check')end
  assert(e.session:request('en'));e.session:update()
  assert(e.language=='pt-BR'and e.session.error and S.encode(game.save)==before,'Failed switch did not preserve the current language and progress')
  e.session:close();wait(3);love.graphics.captureScreenshot('ptbr-auto-title.png');wait(2)
  while game.stack:top()do game.stack:pop()end
  local world=require('src.world.OverworldController');local gen=V.generation()
  game.stack:push(world,gen==2 and 'CHERRYGROVE_POKECENTER1_F'or game.save.player.map,gen==2 and 3 or game.save.player.x,gen==2 and 3 or game.save.player.y,'up')
  for _=1,240 do if e.session:canSwitch()then break end;wait(1)end
  assert(e.session:canSwitch(),'World did not settle')
  before=S.encode(game.save);local map,x,y=world.map.id,world.player.x,world.player.y
  assert(e.session:request('en'));e.session:update();assert(e.language=='en',e.session.error)
  assert(e.session:request('pt-BR'));e.session:update();assert(e.language=='pt-BR',e.session.error)
  assert(S.encode(game.save)==before and world.map.id==map and world.player.x==x and world.player.y==y,'World language switch changed progress or position')
  if gen==2 then
   local Box=require('src.render.TextBox');local create=Box.new;local spoken={}
   Box.new=function(owner,t,...)spoken[#spoken+1]=t;return create(owner,t,...)end
   world:interact();for _=1,180 do if #spoken>0 then break end;wait(1)end;Box.new=create
   local prose=table.concat(spoken,'\n');assert(prose:find('Bem',1,true)or prose:find('bem',1,true),'Actual nurse did not speak Portuguese: '..prose)
   print('PTBR_AUTO_NURSE',version,prose)
  end
  wait(4);love.graphics.captureScreenshot('ptbr-auto-world.png');wait(2)
  print('PTBR_AUTO_GAME_OK',version,require('src.link.Json').encode(e.coverage.applied))
 end,debug.traceback)
 if not ok then print('PTBR_AUTO_GAME_FAILED',why)end
 love.event.quit(ok and 0 or 1)
end
