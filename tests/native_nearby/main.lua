-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local cfg,Game,near,started,finished,proof,battleSeen,original,bytes,path,centerCount,speciesBefore
io.stdout:setvbuf('no')
local elapsed=0
local function json()return require('src.link.Json')end
local function finish(ok,why)
 if finished then return end;finished=true
 local disk=require('src.core.SaveData').persistenceFs()
 local restored=started and Game.save==original
 local unchanged=path and disk.read(path)==bytes
 local traded=Game and speciesBefore and Game.save.party[1].species~=speciesBefore
 if ok and(cfg.mode=='trade'and(not traded or not restored or unchanged)or cfg.mode~='trade'and(not proof or not battleSeen or not restored or not unchanged))then ok=false;why='Native link result or save persistence missing'end
 local f=assert(io.open(cfg.result,'wb'));f:write(json().encode({ok=ok,reason=tostring(why or''),edition=cfg.edition,role=cfg.role,mode=cfg.mode,sentSpecies=speciesBefore,receivedSpecies=Game and Game.save.party[1].species,tradePersisted=traded and not unchanged or false,proof=proof,discovered=started==true,battleSeen=battleSeen==true,recognizedCenters=centerCount,adventureRestored=restored==true,saveUnchanged=unchanged==true}));f:close()
 if near then near:close()end
 love.event.quit(ok and 0 or 1)
end
function love.load()
 local f=assert(io.open(os.getenv('RETRO_NEAR_CONFIG'),'rb'));cfg=json().decode(f:read('*a'));f:close()
 require('src.core.SaveIdentity').migrateLegacy=function()return 0 end
 require('src.core.SaveData').otherLocations=function()return{}end
 local ffi=require('ffi');pcall(ffi.cdef,'int PHYSFS_mount(const char*, const char*, int);')
 local lib=ffi.load(os.getenv('RETRO_LINK_PHYSFS'))
 assert(lib.PHYSFS_mount(cfg.cache..'/data/generated','data/generated',0)~=0)
 assert(lib.PHYSFS_mount(cfg.cache..'/assets/generated','assets/generated',0)~=0)
 require('src.core.GameVersion').set(cfg.edition)
 Game=require('src.core.Game');Game.loadWithoutMods=true;Game:load();Game.stack:init()
 local opts=Game.save.options;opts.vsync='off';opts.textSpeed='fast';opts.musicVolume=0;opts.soundVolume=0;opts.masterVolume=0;Game:applyOptions(opts)
 local centers={};local Lobby=require('src.ui.CenterLobby');for id,def in pairs(Game.data.maps)do local key=Lobby.center({data=Game.data,overworld={map={id=id,def=def}}});if key then centers[key]=true end end;centerCount=0;for _ in pairs(centers)do centerCount=centerCount+1 end;assert(centerCount>0,'Imported Centers are recognized')
 if cfg.mode=='centers'then local f=assert(io.open(cfg.result,'wb'));f:write(json().encode({ok=true,edition=cfg.edition,recognizedCenters=centerCount}));f:close();finished=true;love.event.quit(0);return end
 Game.save.party={}
 for _,species in ipairs(require('src.core.GameVersion').generation()>=4 and{25,16,19}or{'PIKACHU','PIDGEY','RATTATA'})do
  local mon=require('src.pokemon.Pokemon').new(Game.data,species,50);local found
  for i,m in ipairs(mon.moves)do local d=Game.data.moves[m.id];if d and(tonumber(d.power)or 0)>0 then found=i;break end end
  assert(found);mon.moves[1],mon.moves[found]=mon.moves[found],mon.moves[1];Game.save.party[#Game.save.party+1]=mon
 end
 if cfg.mode=='trade'and cfg.role=='right'then Game.save.party[1],Game.save.party[2]=Game.save.party[2],Game.save.party[1]end
 speciesBefore=Game.save.party[1].species
 Game.save.player.name=cfg.role;Game:continueGame(Game.save);original=Game.save
 assert(require('src.core.SaveData').writeSlot(cfg.edition,'slot1',Game.save));assert(require('src.core.SaveData').setActiveSlot(cfg.edition,'slot1'))
 local B=require('src.link.LinkBattle')
 for _,key in ipairs({'newHost','newGuest'})do local factory=B[key];B[key]=function(game,net,opts)opts.onFinished=function(p)proof=p end;return factory(game,net,opts)end end
 near=assert(require('src.link.Nearby').new(Game,cfg.mode or'battle'))
end
function love.update(dt)
 if finished or not cfg then return end;elapsed=elapsed+dt
 if elapsed>(cfg.timeout or 120) then return finish(false,'Timed out during native LAN discovery or battle')end
 if not started then
  if not progressAt or elapsed-progressAt>5 then local peers=0;for _ in pairs(near.peers)do peers=peers+1 end;print('NEAR '..cfg.role..' '..near.id..' '..near.fingerprint..' '..near.phase..' peers='..peers..' address='..tostring(near.net.address)..' error='..tostring(near.error)..' udp='..tostring(near.udp:getsockname()));progressAt=elapsed end
  near:update()
  if cfg.role=='left'and near.phase=='listening'then for id in pairs(near.peers)do near:request(id);break end end
  if cfg.role=='right'and near.phase=='incoming'then near:respond(true)end
  if near.phase=='accepted'then
   local net,host,mode=near:take();near=nil
   assert(require('src.link.LocalLink').start(Game,net,mode,host));started=true
   local state=require('src.link.LocalLink').active.state;local exit=state.exitWith;state.exitWith=function(self,message,reason)if message then print('LOCAL LINK EXIT '..tostring(message))end;return exit(self,message,reason)end
   local S=require('src.core.SaveData');path='saves/'..cfg.edition..'/'..'slot1.lua';bytes=S.persistenceFs().read(path);assert(bytes,'Native local checkpoint exists')
  end
  return
 end
 for _=1,6 do
  local top=Game.stack:top()
  if top and top.kind=='link'then battleSeen=true;top.moveIndex=1 end
  Game.input:keyreleased('return');Game.input:keypressed('return')
  local ok,why=pcall(Game.step,Game,1/60);if not ok then return finish(false,why)end
  require('src.link.LocalLink').tick(Game)
  if cfg.mode=='trade'and not Game.linkSession and Game.stack:top()==Game.overworld and Game.save.party[1].species~=speciesBefore then return finish(true,'Native nearby trade committed on both devices')end
  if not Game.linkSession and not proof and cfg.mode~='trade'then return finish(false,'Native link exited before battle completion')end
  if proof and not Game.linkSession then return finish(true,'Native nearby battle completed with mutual consent')end
 end
end
function love.draw()if Game and started then local ok,why=pcall(Game.draw,Game);if not ok then finish(false,why)end else love.graphics.clear(.02,.03,.05)end end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());if cfg then pcall(finish,false,err)end;return function()return 1 end end
