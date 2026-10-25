-- Launch a community match in an isolated copy of one selected save party.
-- No overworld continuation or battery-save write is needed. The existing
-- LinkState/LinkBattle own transport, compatibility and battle simulation.
local Arena={}
local pending,notice
local Auth=require('src.cloud.RetroCloud')
local function clone(v) local S=require('src.core.SaveSerializer');return S.decode(S.encode(v)) end
function Arena.queue(cup,match,slot)
 local account=Auth.accountId()
 if not Auth.signedIn() or type(cup)~='table' or tostring(cup.account_id)~=account then return nil,'Sign in again before starting a battle.' end
 if cup.state~='running' or match.state~='ready' or (match.left~=account and match.right~=account) then return nil,'This pairing is not ready for your account.' end
 if match.left~=account and (type(match.room)~='string' or not match.room:match('^[A-Z0-9]+$') or #match.room~=6) then return nil,'The host must open the battle first. Refresh the lobby when their room is ready.' end
 local save,why=require('src.core.SaveData').peekSlot(cup.edition,slot)
 if not save then return nil,why or 'Choose an existing save.' end
 if type(save.party)~='table' or #save.party~=cup.team_size then return nil,'This cup needs exactly '..tostring(cup.team_size)..' party members. Prepare your team in the selected save.' end
 for _,mon in ipairs(save.party) do if mon.isEgg or mon.egg or mon.eggSteps and mon.eggSteps>0 then return nil,'Eggs cannot enter a battle team.' end end
 pending={cup=clone(cup),match=clone(match),save=clone(save),account=account}
 return true
end
function Arena.cancelPending() pending=nil end
function Arena.takeNotice() local n=notice;notice=nil;return n end
function Arena.consume(game)
 local request=pending;pending=nil
 if not request then return end
 local cup,match,account=request.cup,request.match,request.account
 if not Auth.signedIn() or Auth.accountId()~=account or require('src.core.GameVersion').get()~=cup.edition then notice={account=account,id=cup.id,text='The account or edition changed. Reopen your pairing.'};return end
 local Handshake=require('src.link.Handshake')
 if not Handshake.onlineAllowed(game) then notice={account=account,id=cup.id,text='Disable gameplay mods before entering an online battle. Verified translations may stay enabled.'};game:returnToLauncher();return end
 local originalSave,write,back=game.save,game.writeSave,game.returnToLauncher
 game.save=request.save;game.retroArena=true
 game.writeSave=function() return nil,'Arena parties are temporary. Return to the library to save your adventure.' end
 local Link=require('src.link.LinkState');local Net=require('src.link.Net')
 local state=Link.new(game);state.net=Net.new();state.discordCodeSet=true
 local cleaned=false
 local function clean(message)
  if cleaned then return end;cleaned=true
  if state.roomTask then state.roomTask:cancel();state.roomTask=nil end
  if state.net then state.net:close() end
  game.linkSession=nil;game.linkNet=nil;game.retroArena=nil
  game.save=originalSave;game.writeSave=write;game.returnToLauncher=back
  notice={account=account,id=cup.id,text=message or 'Battle closed. Confirm the winner in your pairing; both players must agree.'}
 end
 game.returnToLauncher=function(self) clean();return back(self) end
 state.exitWith=function(self,message) clean(message);return back(game) end
 state.sendHello=function(self,mode)
  self.myHello=Handshake.hello(game,mode)
  self.myHello.arena={tournament=cup.id,match=match.id,account=account,edition=cup.edition,team_size=cup.team_size,level=cup.level}
  self.net:send(self.myHello)
 end
 local decide=state.decideCompat
 state.decideCompat=function(self,mode,host)
  local peer=self.peerHello and self.peerHello.arena
  local expected=host and match.right or match.left
  if mode~='battle' or not peer or peer.tournament~=cup.id or peer.match~=match.id or peer.account~=expected or peer.edition~=cup.edition or peer.team_size~=cup.team_size or peer.level~=cup.level then
   return self:exitWith('The other client does not match this tournament pairing and its rules.')
  end
  decide(self,mode,host)
  if self.stage=='battleOptions' then self.forceLevel=cup.level;self:startMode('battle',true) end
 end
 local update=state.update
 state.update=function(self,dt)
  if not Auth.signedIn() or Auth.accountId()~=account then return self:exitWith('Sign in again before continuing an online battle.') end
  if self.roomTask then
   local result=self.roomTask:poll()
   if result then self.roomTask=nil;if not (result.kind=='done' and result.first) then return self:exitWith(result.error or result.second or 'The lobby could not publish this room.') end end
  end
  update(self,dt)
  if cleaned then return end
  if self.stage=='onlineHosting' and self.net.code and not self.roomPublished then
   self.roomPublished=true;local code=self.net.code
   self.roomTask=require('src.cloud.Task').new(function() return require('src.cloud.Tournaments').request('PUT',cup.id,'room',{code=code},match.id) end)
   if not self.roomTask then return self:exitWith('Background networking is unavailable.') end
  end
  if self.stage=='modeSelect' then
   self:sendHello('battle');self.pendingMode='battle';self.helloWait=0;self.stage='waitHello'
  end
 end
 game.stack:push(state)
 local ok
 if match.left==account then ok=state.net:hostOnline();state.stage='onlineHosting'
 else ok=state.net:joinOnline(nil,match.room);state.stage='onlineJoining' end
 if not ok then state:exitWith('The battle relay could not connect. Retry from the lobby.') end
end
return Arena
