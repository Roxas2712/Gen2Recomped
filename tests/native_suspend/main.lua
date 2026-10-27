-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real native battle, private HTTPS cloud, two fresh account-bound profiles.
io.stdout:setvbuf("no")
local cfg,Game,Task,Auth,job,phase,done,expected,anchorError
local progressAt=0;local startedAt=0
local S;local J;local initialPP;local frames=0;local ticks=0;local animationTicks=0;local idleTicks=0;local captureInfo
local function write(file,value)local f=assert(io.open(file,'wb'));f:write(require('src.link.Json').encode(value));f:close()end
local function summary()
 local b=Game.stack:active();local p=Game.save.party[1]
 return {turn=b.turnCount or 0,phase=b.phase,hp=p.hp,enemyHp=b.enemy and b.enemy.mon.hp,pp=p.moves[1].pp,rng=love.math.getRandomState(),species=p.species}
end
local function finish(ok,why)
 if done then return end;done=true
 write(cfg.result,{ok=ok,edition=cfg.edition,role=cfg.role,phase=phase,reason=tostring(why or ''),ticks=ticks,capture=captureInfo})
 print('SUSPEND '..cfg.edition..' '..cfg.role..' '..tostring(ok)..' '..tostring(why or''));love.event.quit(ok and 0 or 1)
end
function love.errorhandler(why)io.stderr:write(tostring(why)..'\n'..debug.traceback());if cfg then pcall(finish,false,why)end;return function()return 1 end end
local function task(name,fn)phase=name;job=assert(Task.new(fn))end
local function suspend()
 local b=Game.stack:active()
 assert(b.player.mon.hp<b.player.mon.stats.hp or b.enemy.mon.hp<b.enemy.mon.stats.hp,'Battle has actual damage')
 assert(Game.save.party[1].moves[1].pp<initialPP,'Battle has spent PP')
 local capsule,why=J.capture(Game);assert(capsule,why)
 if (cfg.idleTicks or 0)>0 then
  local _,code,detail=require('src.core.Checkpoint').capture(Game)
  assert(capsule.anchor.kind=='battle','Long battle must rebase on a native battle checkpoint: '..tostring(detail or code))
  assert(#capsule.steps<=J.BATTLE_CHECKPOINT_TICKS+120,'Long battle must not replay its entire history')
 end
 captureInfo={kind=b.kind,anchor=capsule.anchor.kind,tailSteps=#capsule.steps,bytes=#J.encode(capsule),idleTicks=idleTicks}
 local kept,why=require('src.storage.SuspendStore').keep(Game);assert(kept,why)
 expected={witness=S.encodeExact(J.witness(Game)),animation=not not b.gen3AnimPlaying}
 assert(not cfg.animation or expected.animation,'Requested snapshot must be inside a native move animation')
 task('upload',function()
  local store=assert(Auth.open());local result,why=require('src.import.CloudSync').syncOne(store,cfg.edition,'slot1',true);assert(result,why);return result
 end)
end
local function prepare()
 assert(require('src.storage.AccountStorage').bind())
 Game=require('src.core.Game');Game.loadWithoutMods=not cfg.withMod;Game:load()
 if cfg.withMod then
  local loaded={};for _,m in ipairs(Game.modStatus.loaded or{})do loaded[m.id]=true end
  assert(loaded.qa_suspend_counter and loaded.german_rom_source,'Both native suspend mods must load')
 end
 S=require('src.core.SaveSerializer');J=require('src.core.SuspendJournal')
 initialPP=assert(Game.data.moves[cfg.move or'SWIFT']).pp
 local trainer
 if cfg.trainer then
  local highest=-1
  for id,record in pairs(Game.data.trainers or {})do
   for index,party in ipairs(record.parties or {})do
    local first=party[1]
    local species=first and Game.data.pokemon[first.species]
    if species and species.dex==129 and(first.level or 0)>highest then
     highest=first.level;trainer={id=id,index=index}
    end
   end
  end
  assert(trainer,'A native Magikarp trainer is required for the trainer probe')
 end
 local world=Game.overworld;local update=world.update
 world.update=function(self,dt)
  if Game.input:wasPressed('a')and not Game.save.flags.CLOUD_SUSPEND_STARTED then
   Game.save.flags.CLOUD_SUSPEND_STARTED=true
   local wild=require('src.core.Gen2SpeciesNames').registryId(Game.data.pokemon,'MAGIKARP')
   self.runner:run({{'start_battle',trainer and'trainer'or'wild',trainer and trainer.id or wild,trainer and trainer.index or 35},{'set_flag','CLOUD_SUSPEND_RETURNED'}})
  end
  return update(self,dt)
 end
 if cfg.role=='source'then
  Game.save.options.vsync='off';Game.save.options.textSpeed='fast';Game.save.options.audioMuted=true;Game:applyOptions(Game.save.options)
  Game.save.party={require('src.pokemon.Pokemon').new(Game.data,require('src.core.GameVersion').generation()==1 and'ONIX'or'SHUCKLE',35)}
  local mon=Game.save.party[1];mon.moves={{id=cfg.move or'SWIFT',pp=initialPP,maxPP=initialPP}}
  local p=Game.save.player;world:_checkpointRebuild({map=p.map,x=p.x,y=p.y,facing=p.facing})
  if Game.stack.worldOwner then Game.stack.worldState=world;Game.stack.worldOwner.world=world;Game.stack.states={}else Game.stack.states={world}end
  Game.save.flags.CLOUD_SUSPEND_STARTED=nil;Game.save.flags.CLOUD_SUSPEND_RETURNED=nil
  assert(require('src.core.SaveData').ensurePlaythroughId(Game.save))
  local save=require('src.core.SaveData');assert(save.writeSlot(cfg.edition,'slot1',Game.save));assert(save.setActiveSlot(cfg.edition,'slot1'));assert(Game:writeSave())
  phase='anchor'
 else
  task('download',function()
   local store=assert(Auth.open());local result,why=require('src.import.CloudSync').restoreVersions(store,{cfg.edition});assert(result,why);return result
  end)
 end
end
function love.load()
 startedAt=love.timer.getTime()
 local f=assert(io.open(os.getenv('RETRO_SUSPEND_CONFIG'),'rb'));cfg=require('src.link.Json').decode(f:read('*a'));f:close()
 love.audio.setVolume(0);love.math.setRandomSeed(cfg.role=='source'and 2712 or 999)
 require('src.core.SaveIdentity').migrateLegacy=function()return 0 end
 require('src.core.SaveData').otherLocations=function()return {}end
 require('src.storage.AccountStorage').enable()
 local ffi=require('ffi');pcall(ffi.cdef,'int PHYSFS_mount(const char*,const char*,int);');local lib=ffi.load(cfg.library)
 if not cfg.privateGameCache then
  assert(lib.PHYSFS_mount(cfg.cache..'/data/generated','data/generated',0)~=0);assert(lib.PHYSFS_mount(cfg.cache..'/assets/generated','assets/generated',0)~=0)
 elseif cfg.role=='source' then
  assert(lib.PHYSFS_mount(cfg.cache,'qa-import',0)~=0)
 end
 require('src.core.GameVersion').set(cfg.edition)
 Auth=require('src.cloud.RetroCloud');Auth.API=cfg.api;Task=require('src.cloud.Task')
 task('login',function()return require('src.cloud.NativeAccount').login(cfg.email,cfg.password)end)
end
local function step(button)
 Game.input:keyreleased('return');if button then Game.input:keypressed('return')end
 Game:step(1/60);ticks=ticks+1
end
function love.update(dt)
 if cfg and love.timer.getTime()-progressAt>5 then
  progressAt=love.timer.getTime();local top=Game and Game.stack and Game.stack:top()
  print('SUSPEND_PROGRESS '..tostring(cfg.role)..' phase='..tostring(phase)..' ticks='..ticks..' idle='..idleTicks..' native='..tostring(top and top.phase)..' turn='..tostring(top and top.turnCount)..' anim='..tostring(top and top.gen3AnimPlaying))
 end
 if done then return end;frames=frames+1
 if love.timer.getTime()-startedAt>(cfg.timeout or 180)-5 then return finish(false,'Timed out '..tostring(phase)..' '..tostring(anchorError))end
 if job then
  local r=job:poll();if not r then return end;job=nil
  if r.kind~='done'or not r.first then return finish(false,r.second or r.error)end
  if phase=='login'then
   if cfg.privateGameCache then
    task('private-game',function()
     assert(require('src.storage.AccountStorage').bind())
     local store=assert(Auth.open());local cache=require('src.storage.GameCache')
     if cfg.role=='source'then
      local prefix=require('src.core.GameVersion').cachePrefix(cfg.edition)
      local function path(p)assert(p:sub(1,#prefix)==prefix);return 'qa-import/'..p:sub(#prefix+1)end
      local fs={read=function(p)return love.filesystem.read(path(p))end,getInfo=function(p)return love.filesystem.getInfo(path(p))end,
       getDirectoryItems=function(p)return love.filesystem.getDirectoryItems(path(p))end}
      local id,why=cache.upload(store,cfg.edition,nil,fs);assert(id,why)
      -- Use the same private restore path on both profiles for the game boot.
      local restored,why=cache.restore(store,cfg.edition,id);assert(restored,why);return restored
     end
     assert(not love.filesystem.getInfo('data/generated/pokemon.lua'),'Target must start without imported game data')
     local restored,why=cache.restore(store,cfg.edition);assert(restored,why);return restored
    end);return
   end
   prepare();return
  elseif phase=='private-game'then
   local ok,why=require('src.import.CacheFs').mountVersion(cfg.edition);assert(ok,why)
   assert(require('src.storage.GameCache').prefix(cfg.edition),'Boot must use the account-private restored import')
   prepare();return
  elseif phase=='upload'then phase='nextturn'
  elseif phase=='download'then
   local saves=require('src.core.SaveData');local slots=saves.listSlots(cfg.edition);assert(#slots==1,'Cloud restored one normal save')
   assert(saves.setActiveSlot(cfg.edition,slots[1].id));local loaded=assert(saves.load());local id=loaded.meta.playthroughId
   local capsule=assert(require('src.storage.SuspendStore').read(cfg.edition,id));assert(require('src.storage.SuspendStore').matchesNormal(capsule,cfg.edition,slots[1].id),'Cloud normal-save fingerprint must match')
   local oracle=assert(io.open(cfg.expected,'rb'));expected=assert(S.decode(oracle:read('*a')));oracle:close()
   assert(S.encodeExact(capsule.witness)==expected.witness,'Cloud retained the exact battle capsule')
   Game.stack.states={{screenId='TitleState'}};if Game.stack.worldOwner then Game.stack.worldState=nil end
   assert(Game:continueGame(loaded));assert(Game.stack:active().isBattleState,'Continue resumed the battle directly: '..tostring(require('src.ui.RetroOverlay').notice))
   assert(S.encodeExact(J.witness(Game))==expected.witness,'Fresh logged-in profile recreated exact HP, PP, native phases and RNG')
   assert(not expected.animation or Game.stack:active().gen3AnimPlaying,'Native move animation was reconstructed too')
   phase='nextturn'
  end
 end
 if phase=='anchor'then
  step(false)
  local cap,why=J.capture(Game);anchorError=why
  if cap then step(true);phase='battle'end
 elseif phase=='battle'or phase=='animation'or phase=='nextturn'then
  for _=1,4 do
   local b=Game.stack:active()
   if not b.isBattleState then step(true)
   elseif phase=='battle'and b.phase=='menu'and(b.turnCount or 0)>=1 and b.gen3AnimPlaying then step(false)
   elseif phase=='battle'and b.phase=='menu'and(b.turnCount or 0)>=1 and idleTicks<(cfg.idleTicks or 0)then
    if idleTicks==0 then
     local cp,code,detail=require('src.core.Checkpoint').capture(Game)
     if not cp then local ok,why=pcall(require('src.core.CheckpointBattle').capture,Game,b,function(v)return assert(S.decode(S.encodeExact(v)))end);error(tostring(detail)..' / '..tostring(why))end
    end
    -- Advance actual logic and journal ticks without rendering every idle
    -- decision. Thirty simulated minutes must not spend thirty real minutes
    -- drawing an unchanged battle menu.
    local count=math.min(240,(cfg.idleTicks or 0)-idleTicks)
    for _=1,count do idleTicks=idleTicks+1;step(false)end
   elseif phase=='animation'and b.gen3AnimPlaying then
    animationTicks=animationTicks+1
    if animationTicks>=5 then suspend();return else step(true)end
   elseif phase~='animation'and b.phase=='menu'and(b.turnCount or 0)>=(phase=='battle'and 1 or 2)then
    if phase=='battle'then
     if cfg.animation then phase='animation';step(true)else suspend()end
    else
     local result=summary()
     if cfg.role=='source'then expected.next=result;local f=assert(io.open(cfg.expected,'wb'));f:write(S.encodeExact(expected));f:close();return finish(true,'Uploaded a damaged native battle '..(cfg.animation and 'during a move animation' or 'after turn 1')..'; recorded deterministic turn 2')
     else
      assert(S.encodeExact(result)==S.encodeExact(expected.next),'The next native turn must match the original device')
      b.result='win';b:finish();phase='return'
     end
    end
    return
   else step(true)end
  end
 elseif phase=='return'then
  step(true)
  if Game.save.flags.CLOUD_SUSPEND_RETURNED then return finish(true,'Login, cloud download, exact Continue, matching next turn and original story continuation passed')end
 end
end
function love.draw()if Game then Game:draw()end end
