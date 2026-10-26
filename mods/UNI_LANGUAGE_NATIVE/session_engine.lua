-- In-process language handoff. Uses the stock session teardown/boot paths,
-- keeps unsaved progress in memory, and never writes a normal game save.
local E={}
local function copy(value)
 local S=require('src.core.SaveSerializer')
 return assert(S.decode(S.encode(value),{maxBytes=64*1024*1024,maxNodes=2000000,maxDepth=80}))
end
local function gen()return require('src.core.GameVersion').generation()end
function E.inspect(game)
 if not game or not game.save then return nil,'not_playing' end
 if game.unionPresence then return nil,'busy'end
 if game.arena or game.phase=='arena' or game.phase=='quest_log' then return nil,'busy' end
 if game.capturePath then return nil,'busy' end
 local g=gen()
 local map=game.session and game.session.map or game.world and game.world.map and game.world.map.id or game.overworld and game.overworld.map and game.overworld.map.id
 if map and (map:find('UNION') or map:find('TRADE') or map:find('COLOSSEUM') or map:find('MOBILE'))then return nil,'busy'end
 if g==1 then
  local result=require('src.core.Checkpoint').inspect(game)
  return result.canCapture and result.kind=='overworld' or nil,result.reason or 'busy'
 elseif g==2 then
  local w=game.world
  if not w or not w.map or not w.player or game.phase~='play' then return nil,'not_playing' end
  if game.stack:top()~=nil or w:busy() or w.player.moving then return nil,'busy' end
  return true
 else
  if game.phase~='field' or not game.session then return nil,'not_playing' end
  local P=require('src.core.game3.player')
  local Space=require('src.core.game3.scripting.space')
  local Stack=require('src.ui.game3.stack')
  local Battle=require('src.core.game3.battle');local Field=require('src.core.game3.field')
  if (Battle.isActive and Battle.isActive()) or (Field.isLocked and Field.isLocked()) then return nil,'busy'end
  if P.moving or P.jumping or P.boulderPush or (Space.vm and Space.vm:isRunning()) then return nil,'busy' end
  if Stack.top and Stack.top() then return nil,'busy' end
  local Warp=require('src.core.game3.warp')
  if Warp.isBusy and Warp.isBusy() then return nil,'busy' end
  return true
 end
end
function E.capture(game)
 local ok,why=E.inspect(game);assert(ok,why)
 local g=gen();local save;local nativeSession;local overworld
 if g==1 then
  local cp=assert(require('src.core.Checkpoint').capture(game));save=cp.save;overworld=cp.runtime.overworld
 elseif g==2 then save=game:snapshotSave()
 else
  require('src.core.game3.scripting.space').persistSession(nil,game)
  local P=require('src.core.game3.player');local s=game.session
  s.x,s.y,s.facing=P.cellX,P.cellY,P.facing
  s.surfing,s.underwater,s.biking=P.surfing==true,P.underwater==true,P.biking==true
  s.bikeType,s.elevation=P.bikeType,P.elevation
  require('src.core.game3.rng').captureToSession(s)
  save=require('src.core.game3.save_schema_firered').toSaveTable(s)
  local native={};for k,v in pairs(s)do if k~='options'then native[k]=v end end
  nativeSession=copy(native)
  local Pokemon=require('src.core.game3.pokemon');local seen={}
  local function defaults(value)
   if type(value)~='table' or seen[value]then return end;seen[value]=true
   if value.species and value.moves and value.name==Pokemon.name(Pokemon.speciesOf(value))then value.name=nil end
   for _,child in pairs(value)do if type(child)=='table'then defaults(child)end end
  end
  defaults(nativeSession.party);defaults(nativeSession.storage);defaults(nativeSession.daycare)
 end
 local rows={};for k,v in pairs(save)do if k~='options'then rows[k]=v end end
 local rng=love.math.getRandomState and love.math.getRandomState()
 local mods={};for _,row in ipairs(game.mods.loaded or {})do mods[#mods+1]=type(row)=='table' and (row.id or row.manifest and row.manifest.id) or row end
 return {generation=g,version=require('src.core.GameVersion').get(),save=copy(rows),rng=rng,mods=mods,sessionStartedAt=game.sessionStartedAt,nativeSession=nativeSession,overworld=overworld}
end
local function adopt(game,snapshot)
 local save=copy(snapshot.save)
 if snapshot.generation==1 then
  local w=snapshot.overworld
  if w then save.player.map=w.map;save.player.x=w.x;save.player.y=w.y;save.player.facing=w.facing;save.player.surfing=w.surfing end
  game:restoreCheckpointSave(save)
 elseif snapshot.generation==2 then game:continueGame(save)
 else
  local Schema=require('src.core.game3.save_schema_firered')
  -- A language handoff is not a cartridge CONTINUE: preserve transient
  -- session fields too, without normal-save migration/reset side effects.
  local s=assert(snapshot.nativeSession,'Missing native session snapshot');s=copy(s)
  local Pokemon=require('src.core.game3.pokemon')
  local seen={};local function names(value)
   if type(value)~='table' or seen[value]then return end;seen[value]=true
   if value.species and value.moves and not value.name then value.name=Pokemon.name(Pokemon.speciesOf(value))end
   for _,child in pairs(value)do if type(child)=='table'then names(child)end end
  end
  names(s.party);names(s.storage);names(s.daycare)
  game.session=s;require('src.core.game3.options').bind(s,game.options)
  game:adoptSave(s);game._modSaveAdopted=true
  game.save=Schema.toSaveTable(s);game.phase='field';game.boot=nil
  require('src.core.game3.bg').reset();require('src.core.game3.oam').reset()
  local Map=require('src.core.game3.map');Map._announced=nil;Map._nextEnterVia='checkpoint'
  require('src.core.game3.runtime').start(nil,game,s,{reason='language-switch'})
  Map._nextEnterVia=nil
  require('src.core.game3.rng').restoreFromSession(s)
 end
 local Runtime=require('src.mods.Runtime')
 if snapshot.generation~=2 then Runtime.emit('save.loaded',{save=snapshot.generation==3 and game.session or game.save,meta=game.save.meta})end
 if snapshot.generation==1 then Runtime.emit('checkpoint.restored',{game=game,kind='overworld'})end
 if snapshot.rng and love.math.setRandomState then love.math.setRandomState(snapshot.rng)end
 game.sessionStartedAt=snapshot.sessionStartedAt or os.time()
end
-- main.lua owns the current Game reference. A small forwarding shell keeps
-- that reference valid while the actual generation-specific owner is rebuilt.
-- All engine/mod callbacks receive the fresh real owner, never the shell.
local function shell(lifecycle,old,fresh)
 local bridge=lifecycle.__ulaGameShell
 if not bridge or bridge.current~=old then
  bridge={root=old,bound={}};lifecycle.__ulaGameShell=bridge
  for k in pairs(old)do old[k]=nil end
  setmetatable(old,{
   __index=function(_,key)
    local target=bridge.current;local value=target and target[key]
    if type(value)~='function'then return value end
    local binding=bridge.bound[key]
    if not binding or binding.value~=value or binding.target~=target then
     binding={value=value,target=target,call=function(first,...)
      if first==bridge.root then return value(target,...)end
      return value(first,...)
     end};bridge.bound[key]=binding
    end
    return binding.call
   end,
   __newindex=function(_,key,value)bridge.current[key]=value end,
  })
 end
 bridge.current=fresh;bridge.bound={}
end
function E.rebuild(game,snapshot)
 local L=require('src.core.SessionLifecycle')
 local returnToLauncher,onExit,speed=game.returnToLauncher,game.onExit,game.speedOverride
 local overlay=require('src.render.Assets').__ulaGBOverlay
 if overlay and overlay.clear then overlay.clear()end
 L.endGameSession(game);L.endMountedSession(snapshot.version)
 local Cache=require('src.import.CacheFs');Cache._germanROMOverlay=nil;local V=require('src.core.GameVersion')
 V.set(snapshot.version);Cache.prefix=V.cachePrefix();Cache.mountVersion(snapshot.version)
 local fresh
 if snapshot.generation==1 then
  -- The engine owns this require while no generation loader is installed.
  fresh=require('src.mods.Loader')._game({generation=1})
 elseif snapshot.generation==2 then fresh=require('src.core.Game2').new()
 else fresh=require('src.core.Game3').new()end
 shell(L,game,fresh)
 fresh.returnToLauncher,fresh.onExit=returnToLauncher,onExit
 fresh:load({onExit=onExit})
 local exports=assert(fresh.mods.exports.german_rom_source,'Language mod did not reload')
 local expected=assert(L.__ulaLanguageTransition).language
 assert(exports.language==expected and (expected=='en' or exports.status=='active'),'Language activation failed')
 for _,id in ipairs(snapshot.mods or {})do
  local found=false;for _,loaded in ipairs(fresh.mods.loaded or {})do
   local key=type(loaded)=='table' and (loaded.id or loaded.manifest and loaded.manifest.id) or loaded
   if key==id then found=true end
  end
  assert(found,'Previously active mod did not reload: '..tostring(id))
 end
 adopt(fresh,snapshot);fresh.speedOverride=speed
 -- Retired JIT traces can pin replaced language closures and registries.
 -- Flush only at the session boundary, never during normal play.
 if jit and jit.flush then jit.flush()end
 return fresh,exports
end
return E
