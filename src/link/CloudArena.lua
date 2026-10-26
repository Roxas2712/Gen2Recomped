-- A tournament battle uses an isolated, server-frozen copy of a saved party.
local Arena={}
local pending,notice
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local API=require('src.cloud.Tournaments')
local function clone(v) local S=require('src.core.SaveSerializer');return S.decode(S.encode(v)) end
function Arena.queue(cup,match,slot)
 local account=Auth.accountId()
 if not Auth.signedIn() or type(cup)~='table' or tostring(cup.account_id)~=account then return nil,'Sign in again before starting a battle.' end
 if cup.battle_gate~='native_rules' then return nil,'This edition does not yet have a qualified native link-battle module.' end
 if cup.state~='running' or match.state~='ready' or (match.left~=account and match.right~=account) then return nil,'This pairing is not ready for your account.' end
 local save,why=require('src.core.SaveData').peekSlot(cup.edition,slot)
 if not save then return nil,why or 'Choose an existing save.' end
 if type(save.party)~='table' or #save.party~=cup.team_size then return nil,'This cup needs exactly '..tostring(cup.team_size)..' party members. Prepare your team in the selected save.' end
 for _,mon in ipairs(save.party) do if mon.isEgg or mon.egg or (tonumber(mon.eggSteps) or 0)>0 then return nil,'Eggs cannot enter a battle team.' end end
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
 if not Handshake.onlineAllowed(game) then notice={account=account,id=cup.id,text='Disable gameplay mods before entering an online battle.'};game:returnToLauncher();return end
 local originalSave,write,back=game.save,game.writeSave,game.returnToLauncher
 game.save=request.save;game.retroArena=true
 game.writeSave=function() return nil,'Arena parties are temporary. Return to the library to save your adventure.' end
 local state=require('src.link.LinkState').new(game);state.net=require('src.link.Net').new();state.discordCodeSet=true
 local cleaned,reported,battle,own,peer,started,reportError
 local elapsed,nextPoll=0,0
 local function report(payload)
  if reported or not battle or not own then return end
  local ok,why=require('src.link.ArenaResults').keep(cup.id,match.id,payload)
  if ok then reported=true else reportError='Result could not be saved: '..tostring(why) end
 end
 local function clean(message)
  if cleaned then return end;cleaned=true
  if battle and own and not reported then report({battle=battle.id,ticket=own.ticket,status='aborted',turns=0,digest=require('src.link.ArenaProof').digest({battle=battle.id,status='aborted'})}) end
  if state.arenaTask then state.arenaTask:cancel();state.arenaTask=nil end
  state.net:close();game.linkSession=nil;game.linkNet=nil;game.retroArena=nil
  game.save=originalSave;game.writeSave=write;game.returnToLauncher=back
  notice={account=account,id=cup.id,text=reportError or message or (reported and 'Battle closed. The two native reports are checked automatically; points require agreement.' or 'Battle closed without a league result.')}
 end
 game.returnToLauncher=function(self) clean();return back(self) end
 state.exitWith=function(self,message) clean(message);return back(game) end
 local function startJob(kind,fn)
  state.arenaPurpose=kind;state.arenaTask=Task.new(fn)
  if not state.arenaTask then state:exitWith('Background networking is unavailable.') end
 end
 local function accept(doc)
  if not doc or not doc.battle then return state:exitWith('The native battle could not be found.') end
  local b=doc.battle
  if battle and battle.id~=b.id then return state:exitWith('The pairing was restarted. Reopen its lobby.') end
  battle=b
  for _,t in ipairs(b.teams or {}) do if t.account==account then own=t else peer=t end end
  if b.state~='preparing' and b.state~='ready' then return state:exitWith('This battle is '..tostring(b.state)..'. Reopen the pairing.') end
  if b.state=='ready' then
   if not own or not peer or own.fingerprint~=peer.fingerprint or own.fingerprint~=Handshake.hello(game,'battle').fingerprint then return state:exitWith('The native battle data changed after preflight.') end
   if not require('src.link.ArenaProof').same(require('src.link.Protocol').packParty(game.save.party),own.party) then return state:exitWith('The selected team changed after preflight.') end
   state.arenaContext={seed=b.seed,level=cup.level,peerParty=peer.party,onFinished=function(result)
    local winner=result.result=='win' and account or result.result=='lose' and peer.account or nil
    local payload={battle=b.id,ticket=own.ticket,status=winner and 'complete' or result.result=='draw' and 'draw' or 'aborted',winner=winner and tonumber(winner),turns=result.turns,digest=result.digest}
    report(payload)
   end}
  end
 end
 state.sendHello=function(self,mode)
  if not battle or not own then return self:exitWith('The Bank preflight is incomplete.') end
  self.myHello=Handshake.hello(game,mode)
  self.myHello.arena={tournament=cup.id,match=match.id,account=account,battle=battle.id,nonce=battle.nonce,digest=own.digest,ticket=own.ticket}
  self.net:send(self.myHello)
 end
 local decide=state.decideCompat
 state.decideCompat=function(self,mode,host)
  local a=self.peerHello and self.peerHello.arena
  if mode~='battle' or not a or not peer or a.account~=peer.account or a.tournament~=cup.id or a.match~=match.id or a.battle~=battle.id or a.nonce~=battle.nonce or a.digest~=peer.digest or a.ticket~=peer.ticket then return self:exitWith('The other client does not match this frozen tournament pairing.') end
  decide(self,mode,host)
  if self.stage=='battleOptions' then self.forceLevel=cup.level;self:startMode('battle',true) end
 end
 local update,draw=state.update,state.draw
 state.draw=function(self,...)
  if not started then
   local g=love.graphics;g.setColor(.04,.06,.1);g.rectangle('fill',0,0,512,384);g.setColor(1,1,1)
   local F=require('src.render.Font');F.draw('RETRORECOMPED ARENA',8,12);F.draw('Preparing Bank teams',8,40);F.draw('Waiting for your rival',8,60);F.draw('B: return to lobby',8,112)
  else return draw(self,...) end
 end
 state.update=function(self,dt)
  if cleaned then return end
  if not Auth.signedIn() or Auth.accountId()~=account then return self:exitWith('Sign in again before continuing an online battle.') end
  elapsed=elapsed+dt
  if self.arenaTask then
   local result=self.arenaTask:poll()
   if result then
    local purpose=self.arenaPurpose;self.arenaTask=nil
    if result.kind~='done' or not result.first then return self:exitWith(result.error or result.second or 'The battle service is unavailable.') end
    if purpose=='room' then self.roomPublished=true
    elseif purpose=='roomLookup' then
     for _,m in ipairs(result.first.matches or {}) do if m.id==match.id then match=m end end
    else accept(result.first) end
    if cleaned then return end
   end
  end
  if not started then
   if game.input:wasPressed('b') then return self:exitWith('Battle cancelled before entry.') end
   if elapsed>180 then return self:exitWith('Your rival did not enter in time. Retry from the lobby.') end
   if self.arenaContext and not self.arenaTask then
    local ok
    if match.left==account then ok=self.net:hostOnline();self.stage='onlineHosting';started=true
    elseif match.room then ok=self.net:joinOnline(nil,match.room);self.stage='onlineJoining';started=true
    elseif elapsed>=nextPoll then nextPoll=elapsed+2;startJob('roomLookup',function() return API.request('GET',cup.id) end);return end
    if started and not ok then return self:exitWith('The battle relay could not connect. Retry from the lobby.') end
   elseif not self.arenaTask and elapsed>=nextPoll then
    nextPoll=elapsed+2;startJob('preflight',function() return API.request('GET',cup.id,'battle',nil,match.id) end)
   end
   return
  end
  update(self,dt);if cleaned then return end
  if self.stage=='onlineHosting' and self.net.code and not self.roomPublished and not self.arenaTask then
   local code=self.net.code;startJob('room',function() return API.request('PUT',cup.id,'room',{code=code},match.id) end)
  end
  if self.stage=='modeSelect' then self:sendHello('battle');self.pendingMode='battle';self.helloWait=0;self.stage='waitHello' end
 end
 game.stack:push(state)
 startJob('preflight',function()
  local data,party=require('src.link.ArenaTeam').prepare(game,cup,request.save)
  if not data then return nil,party end
  game.save.party=party
  return API.request('POST',cup.id,'battle',data,match.id)
 end)
end
return Arena
