-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The nearby invitation has already been accepted on both devices.
local L={}
function L.start(game,net,mode,host)
 local ok,why=game:writeSave();if not ok then net:close();return nil,why end
 local original,write=game.save,game.writeSave
 if mode=='battle'then
  local S=require('src.core.SaveSerializer');game.save=S.decode(S.encode(game.save))
  game.writeSave=function()return nil,'Local friend battles do not change your adventure save.'end
 end
 require('src.ui.RetroOverlay').clear()
 local state=require('src.link.LinkState').new(game);state.net=net;state.discordCodeSet=true
 state.stage=host and 'waitHello'or'waitMode';state.pendingMode=host and mode or nil;state.helloWait=0
 local deadline=love.timer.getTime()+60
 local decide=state.decideCompat
 state.decideCompat=function(self,selected,isHost)
  if not self.peerHello then return end
  if selected~=mode then return self:exitWith('The nearby player requested another link mode.')end
  return decide(self,selected,isHost)
 end
 local cleaned=false
 local function cleanup()
  if cleaned then return end;cleaned=true
  if mode=='battle'then game.save=original;game.writeSave=write end
  if L.active and L.active.state==state then L.active=nil end
 end
 local exit=state.exitWith;state.exitWith=function(self,...)cleanup();return exit(self,...)end
 local update=state.update
 state.update=function(self,dt)
  if not self.peerHello and love.timer.getTime()>deadline then return self:exitWith('The nearby player did not complete the native handshake.')end
  if self.stage=='battleRunning' and game.stack:top()==self then return self:exitWith(nil)end
  update(self,dt)
 end
 state:sendHello(host and mode or nil)
 L.active={game=game,state=state,cleanup=cleanup};game.stack:push(state)
 return true
end
function L.tick(game)
 if L.active and (L.active.game~=game or not game.linkSession)then L.active.cleanup()end
end
return L
