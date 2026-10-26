-- Native ROM language UI acceptance; adapted from Uni-Language Ascendant (GPL-3.0).
-- Actual native GBA consumers; no invented dialogue or mocked renderers.
local function wait(n)for _=1,n do coroutine.yield()end end
return function(game)
 for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
 if love.keyboard then love.keyboard.isDown=function()return false end end
 local ok,err=xpcall(function()
  local V=require('src.core.GameVersion');local version=V.get();local e=game.mods.exports.german_rom_source
  assert(e.host=='Gen2Recomped'and e.language=='de'and e.status=='active',e.session.error or e.status)
  if e.startup and e.startup.open then if e.startup.stage=='reset'then assert(e.startup.back())end;local ok,why=e.startup.choose('de');assert(ok,tostring(why))end
  assert(e.localizationBackend=='native-rom-language-v1')
  local S=require('src.core.SaveSerializer');local hash=function(s)return love.data.encode('string','hex',love.data.hash('string','sha256',s))end
  local cache=V.cachePrefix()..'data/generated/'
  local original=assert(loadstring(assert(love.filesystem.read(cache..'constants.lua'))))()
  for _,key in ipairs({'gen3Weather','gen3Layout','gen3BattlerCoords','gen3MoveAnims','gen3HealLocations','gen3NewGameFlags','gen3SystemFlagBase','gen3FRLGBehaviours','gen3Behaviours'})do
   assert(S.encode(original[key]or{})==S.encode(game.data.constants[key]or{}),'Mechanics altered: '..key)
  end
  assert(e.coverage.assets>0 and e.coverage.applied.dex>=386 and e.coverage.applied.abilities==78 and e.coverage.applied.world>=50,'Native font/content/world coverage missing')
  assert(game.data.constants.abilities.OVERGROW.name=='NOTDÜNGER','Ability name missing')
  assert(game.data.pokemon.BULBASAUR.category=='SAMEN','Dex category missing')
  if version=='emerald'then
   local native=assert(loadstring(assert(love.filesystem.read(cache..'scenes.lua'))))()
   local scenes=game.data.scenes
   local Scene=require('src.render.Gen3Scene')
   for role,ids in pairs(native._roles or{})do
    local localized=assert(scenes._roles[role],'Localized scene role missing: '..role)
    assert(#localized==#ids,'Localized scene lost a layer: '..role)
    for _,id in ipairs(localized)do assert(scenes[id]and Scene.image(game.data,id),'Localized scene role cannot render: '..role..' '..id)end
   end
   assert(#Scene.layersOf(game.data,'title')>=2,'Rayquaza/cloud title layers missing')
   print('NATIVE_LANGUAGE_GBA_SCENE_ROLES_OK',version,'title and intro layers render after relocation')
  end
  local P=require('src.pokemon.Pokemon');local mon=P.new(game.data,'BULBASAUR',15)
  mon.ot=game.save.player.name;mon.otId=game.save.player.trainerId or 12345
  local Summary=require('src.ui.Gen3SummaryMenu');local summary=Summary.new(game,{mon=mon})
  assert(summary:natureRecord().name~=(original.natures[mon.nature]or{}).name,'Cached nature name stayed English')
  local memo=table.concat(summary:memoLines(),'\n')
  assert(memo:find('Wesen',1,true)and not memo:find('nature',1,true)and not memo:find('[{}]'),'Native memo untranslated/unresolved: '..memo)
  print('NATIVE_LANGUAGE_GBA_MEMO_OK',version,memo)
  game.save.party={mon};game.save.pokedex=game.save.pokedex or{};game.save.pokedex.seen=game.save.pokedex.seen or{};game.save.pokedex.owned=game.save.pokedex.owned or{}
  game.save.pokedex.seen.BULBASAUR=true;game.save.pokedex.owned.BULBASAUR=true
  local function clear()while game.stack:top()do game.stack:pop()end end
  local function screen(name,state)
   clear();game.stack:push(assert(state));wait(name=='title'and 600 or 4)
   love.graphics.captureScreenshot('ula-'..version..'-full-'..name..'.png');wait(2)
   print('NATIVE_LANGUAGE_GBA_SCREEN_OK',version,name)
  end
  screen('title',game:makeTitleState())
  screen('party',require('src.ui.Gen3PartyMenu').new(game))
  screen('summary',summary)
  summary.page=2;screen('summary-skills',summary)
  summary.page=3;screen('summary-moves',summary)
  screen('bag',require('src.ui.Gen3BagMenu').new(game))
  screen('dex',require('src.ui.Gen3Pokedex').new(game))
  screen('dex-entry',require('src.ui.Gen3DexEntry').new(game,'BULBASAUR'))
  screen('region',require('src.ui.Gen3RegionMap').new(game))
  screen('storage',require('src.ui.Gen3StorageMenu').new(game))
  screen('card',require('src.ui.Gen3TrainerCard').new(game))
  screen('naming',require('src.ui.NamingScreen').new(game,{kind='player'}))
  screen('options',require('src.ui.Gen3Options').new(game))
  if version=='emerald'then
   local nav=require('src.ui.Gen3Pokenav').new(game)
   assert(nav:art('menu')and nav:art('buttons'),'Native Pokenav graphics missing')
   screen('pokenav',nav)
  end
  local Strings=require('src.core.Strings')
  local used=Strings('%s\nused %s!','BISASAM','TACKLE')
  assert(used:find('setzt',1,true)and used:find('TACKLE',1,true),'Native battle move message missing: '..used)
  clear();local w=require('src.world.OverworldController')
  game.stack:push(w,game.save.player.map,game.save.player.x,game.save.player.y,'down');wait(4)
  local battle=require('src.battle.BattleState').newWild(game,'RATTATA',5)
  assert(battle.introText:find('RATTFRATZ',1,true),'Wild battle name missing')
  screen('battle',battle);wait(180)
  love.graphics.captureScreenshot('ula-'..version..'-full-battle-intro.png');wait(2)
  -- Real overworld with a rendered language round trip, preserving in-memory
  -- progress and exact mechanical fields. The ordinary game save is not written.
  clear()
  game.stack:push(w,game.save.player.map,game.save.player.x,game.save.player.y,'down')
  for _=1,180 do if e.session:canSwitch()then break end;wait(1)end
  local saved=S.encode(game.save);local text=hash(S.encode(game.data.text));local world=hash(S.encode(game.data.map_tilesets))
  e.session:open(game);assert(e.session:request('en'));e.session:update();assert(e.language=='en',e.session.error)
  assert(S.encode(game.save)==saved,'English switch changed progress')
  assert(game.data.constants.abilities.OVERGROW.name=='OVERGROW','English ability baseline not restored')
  assert(hash(S.encode(game.data.text))==e.baseTextSha256,'English text baseline not restored')
  e.session:open(game);assert(e.session:request('de'));e.session:update();assert(e.language=='de',e.session.error)
  assert(S.encode(game.save)==saved and hash(S.encode(game.data.text))==text and hash(S.encode(game.data.map_tilesets))==world,'Localized warm round trip changed data/progress')
  wait(4);love.graphics.captureScreenshot('ula-'..version..'-full-world.png');wait(2)
  print('NATIVE_LANGUAGE_GBA_FULL_OK',version,used)
 end,debug.traceback)
 if not ok then print('NATIVE_LANGUAGE_GBA_FULL_FAILED',err)end
 love.event.quit(ok and 0 or 1)
end
