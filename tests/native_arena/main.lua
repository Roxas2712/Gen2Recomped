-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Two isolated clients exercise the native Arena entry, transport and recovery.
local cfg,Game,Task,Auth,job,phase,finished,notice
io.stdout:setvbuf('no')
local initialObject,usedCloud
local faultInjected=false;local blockedRetries=0;local blockedUntil=0;local cancelled=false
local elapsed=0;local frames=0;local sent=false;local proof;local battleSeen=false;local initialSave;local initialBytes;local originalPath
local function json() return require('src.link.Json') end
local function read(p) local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b end
local function write(p,v) local f=assert(io.open(p,'wb'));f:write(json().encode(v));f:close() end
local function finish(ok,why)
 if finished then return end;finished=true
 local disk=require('src.core.SaveData').persistenceFs()
 if ok and (not battleSeen or not usedCloud or Game.save~=initialObject or disk.read(originalPath)~=initialBytes) then ok=false;why='Native battle did not restore the original adventure and save bytes' end
 write(cfg.result,{ok=ok,reason=tostring(why or ''),edition=cfg.edition,role=cfg.role,phase=phase,frames=frames,battleSeen=battleSeen,proof=proof,cloudTransport=usedCloud==true,
   adventureRestored=Game and initialObject and Game.save==initialObject or false,
   saveFileUnchanged=originalPath and disk.read(originalPath)==initialBytes or false,
   scenario=cfg.scenario,faultInjected=faultInjected,blockedRetries=blockedRetries,cancelled=cancelled})
 love.event.quit(ok and 0 or 1)
end
function love.load()
 love.filesystem.createDirectory('native-link-test')
 cfg=json().decode(read(os.getenv('RETRO_LINK_CONFIG')))
 require('src.core.SaveIdentity').migrateLegacy=function() return 0 end
 require('src.core.SaveData').otherLocations=function() return {} end
 require('src.storage.AccountStorage').enable()
 local ffi=require('ffi');pcall(ffi.cdef,'int PHYSFS_mount(const char*, const char*, int);')
 local physfs=ffi.load(os.getenv('RETRO_LINK_PHYSFS'))
 assert(physfs.PHYSFS_mount(cfg.cache..'/data/generated','data/generated',0)~=0,'Mount ROM data')
 assert(physfs.PHYSFS_mount(cfg.cache..'/assets/generated','assets/generated',0)~=0,'Mount ROM assets')
 require('src.link.Net').hostOnline=function() error('Legacy TCP relay was used by the HTTPS test') end
 require('src.link.Net').joinOnline=function() error('Legacy TCP relay was used by the HTTPS test') end
 local CloudNet=require('src.link.CloudNet');local new=CloudNet.new;CloudNet.new=function(...) usedCloud=true;return new(...) end
 require('src.core.GameVersion').set(cfg.edition)
 Auth=require('src.cloud.RetroCloud');Auth.API=assert(cfg.api);Task=require('src.cloud.Task')
 local API=require('src.cloud.Tournaments');local request=API.request
 API.request=function(method,cup,action,payload,match)
  if cfg.scenario=='recovery' and cfg.role=='left' and action=='battle-wire' and love.timer.getTime()<blockedUntil then
   blockedRetries=blockedRetries+1;return nil,'Simulated temporary network outage'
  end
  local a,b,c=request(method,cup,action,payload,match)
  if a and cfg.scenario=='recovery' and cfg.role=='left' and action=='battle-wire' and not faultInjected then
   for _,row in ipairs(payload.messages or {}) do
    local message=json().decode(row.body)
    if message and message.type=='action' then
     faultInjected=true;blockedUntil=love.timer.getTime()+3
     return nil,'Simulated lost response after server committed the action'
    end
   end
  end
  return a,b,c
 end
 local R=require('src.link.ArenaResults');local keep=R.keep
 R.keep=function(cup,match,payload) proof={status=payload.status,turns=payload.turns,digest=payload.digest,winner=payload.winner};return keep(cup,match,payload) end
 phase='login';job=assert(Task.new(function() return require('src.cloud.NativeAccount').login(cfg.email,cfg.password) end))
end
local function prepare()
 assert(require('src.storage.AccountStorage').bind())
 phase='native-load';Game=require('src.core.Game');Game.loadWithoutMods=true;Game:load();Game.stack:init()
 local S=require('src.core.SaveData');local opts=Game.save.options
 opts.textSpeed='fast';opts.musicVolume=0;opts.soundVolume=0;opts.masterVolume=0
 Game:applyOptions(opts)
 Game.save.party={}
 for _,species in ipairs({'PIKACHU','PIDGEY','RATTATA'}) do
  local mon=require('src.pokemon.Pokemon').new(Game.data,species,50)
  local found
  for i,m in ipairs(mon.moves) do local d=Game.data.moves[m.id];if d and (tonumber(d.power) or 0)>0 then found=i;break end end
  assert(found,'Native damaging move: '..species)
  mon.moves[1],mon.moves[found]=mon.moves[found],mon.moves[1]
  Game.save.party[#Game.save.party+1]=mon
 end
 Game.save.player.name=cfg.role=='left' and 'LINK LEFT' or 'LINK RIGHT'
 assert(S.writeSlot(cfg.edition,'slot1',Game.save))
 originalPath='saves/'..cfg.edition..'/slot1.lua'
 initialBytes=S.persistenceFs().read(originalPath)
 initialSave=require('src.core.SaveSerializer').encode(Game.save);initialObject=Game.save
 Game.returnToLauncher=function(self)
  phase='reporting';notice=require('src.link.CloudArena').takeNotice();finishedAt=love.timer.getTime()
 end
 local cup,match=cfg.cup,cfg.match
 cup.account_id=Auth.accountId()
 assert(require('src.link.CloudArena').queue(cup,match,'slot1'))
 phase='preflight';require('src.link.CloudArena').consume(Game)
end
function love.update(dt)
 if finished or not cfg then return end
 elapsed=elapsed+dt
 if not progressAt or elapsed-progressAt>10 then local t=Game and Game.stack:top();print('TEST PROGRESS '..cfg.role..' '..tostring(phase)..' '..tostring(t and t.stage)..' '..tostring(t and t.phase)..' turn='..tostring(t and t.turnCount));progressAt=elapsed end
 if elapsed>150 then return finish(false,'Native network battle timed out: '..tostring(notice and notice.text or phase)) end
 if job then
  local r=job:poll()
  if r then local purpose=phase;job=nil;if r.kind~='done' or not r.first then
    if purpose=='verify-report' then phase='reporting';sent=false;nextVerifyAt=love.timer.getTime()+1;return end
    return finish(false,r.error or r.second or 'Login failed') end
   if purpose=='verify-report' then
    local state=r.first.battle and r.first.battle.state
    if cfg.scenario=='abort' and state=='cancelled' then return finish(true,'Native peer close returned to the lobby without a ranked result.') end
    if cfg.scenario~='abort' and state=='complete' then
     if cfg.role=='left' and cfg.scenario=='recovery' and (not faultInjected or blockedRetries<1) then return finish(false,'The network fault did not run') end
     return finish(true,cfg.scenario=='recovery' and 'Native battle recovered from a lost committed response and both reports completed.' or 'Native battle and both authenticated reports completed.')
    end
    if state~='ready' and state~='verifying' then return finish(false,'Battle service state: '..tostring(state)) end
    phase='reporting';sent=false;nextVerifyAt=love.timer.getTime()+1
   else local ok,why=pcall(prepare);if not ok then return finish(false,why) end end
  end
  return
 end
 if phase=='reporting' then
  require('src.link.ArenaResults').pump()
  if not proof then return finish(false,notice and notice.text or 'No native completion report') end
  if proof.status~='complete' and cfg.scenario~='abort' then return finish(false,notice and notice.text or 'Battle aborted') end
  if not sent and love.timer.getTime()-finishedAt>1 and love.timer.getTime()>=(nextVerifyAt or 0) then
   sent=true;job=assert(Task.new(function() return require('src.cloud.Tournaments').request('GET',cfg.cup.id,'battle',nil,cfg.match.id) end))
   phase='verify-report'
  end
  return
 end
 if phase=='verify-report' then return end
 for _=1,6 do
  frames=frames+1
  local top=Game.stack:top()
  if top and top.kind=='link' then
   battleSeen=true;phase='battle';top.moveIndex=1
   if cfg.scenario=='abort' and cfg.role=='left' and (top.turnCount or 0)>=1 and not cancelled then
    cancelled=true;Game:returnToLauncher();break
   end
   if not screenshot and (top.turnCount or 0)>=1 then screenshot=true;love.graphics.captureScreenshot('native-link-'..cfg.edition..'-'..cfg.role..'.png') end
  end
  Game.input:keyreleased('return');Game.input:keypressed('return')
  local ok,why=pcall(Game.step,Game,1/60)
  if not ok then return finish(false,why) end
  if phase=='reporting' then break end
 end
end
function love.draw()
 if Game and phase~='login' and phase~='native-load' then
  local ok,why=pcall(Game.draw,Game);if not ok then finish(false,why) end
 else love.graphics.clear(.03,.05,.09);love.graphics.setColor(.6,.9,1);love.graphics.print('REAL LINK TEST · '..tostring(phase),30,30) end
end
function love.errorhandler(error)
 print('NATIVE TEST ERROR: '..tostring(error)..'\n'..debug.traceback())
 if cfg then pcall(finish,false,error) end
 return function() return 1 end
end
