package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local account='17';local signed=true;local response;local sent={}
package.loaded['src.cloud.RetroCloud']={accountId=function() return account end,signedIn=function() return signed end}
package.loaded['src.cloud.NativeAccount']={request=function(method,path,payload) sent={method=method,path=path,payload=payload};return response end}
package.loaded['src.cloud.Task']={new=function(fn) return {poll=function() local a,b=fn();return {kind='done',first=a,second=b} end,cancel=function() end} end}
local T=require('src.cloud.Tournaments');local id='11111111-1111-4111-8111-111111111111';local matchid='22222222-2222-4222-8222-222222222222'
response={account_id='17',tournaments={},manage=true}
check(T.request('GET').account_id=='17' and sent.path=='/tournaments','the Arena uses the authenticated native account API')
check(not T.request('GET','../users'),'dynamic tournament IDs cannot escape the route')
response={account_id='18'};check(not T.request('GET',id),'another account response is rejected')
signed=false;check(not T.request('GET'),'guests cannot call the Arena API');signed=true
local save={party={{species='PIKACHU',level=5},{species='PIDGEY',level=5},{species='RATTATA',level=5}},player={name='Fixture'},options={}}
local Saves=require('src.core.SaveData');Saves.peekSlot=function() return save end
local cup={id=id,account_id='17',state='running',edition='red',team_size=3,level=50,generation=1,battle_gate='verified',matches={}}
local match={id=matchid,left='17',right='18',state='ready'};cup.matches={match}
local Arena=require('src.link.CloudArena')
cup.battle_gate='bank_verification_required';check(not Arena.queue(cup,match,'slot1'),'unverified Bank teams cannot enter online tournament battles');cup.battle_gate='verified'
check(Arena.queue(cup,match,'slot1'),'an account may choose its assigned host battle and saved team')
local oldQueue=Arena.queue;match.left='18';match.right='17'
check(not Arena.queue(cup,match,'slot1'),'a guest waits for the assigned host room');match.room='ABC123'
check(Arena.queue(cup,match,'slot1'),'the guest can join the published six-character room')
save.party[3].isEgg=true;check(not Arena.queue(cup,match,'slot1'),'an egg cannot enter a battle party');save.party[3].isEgg=nil
cup.team_size=2;check(not Arena.queue(cup,match,'slot1'),'the chosen party must match the tournament team size');cup.team_size=3
local returned=0;local originalSave={player={name='Original'},party={}}
local net={code='ABC123',close=function(self) self.closed=true end,joinOnline=function() return true end,hostOnline=function() return true end,send=function(self,msg) self.hello=msg end}
package.loaded['src.link.Net']={new=function() return net end}
package.loaded['src.link.Handshake']={onlineAllowed=function() return true end,hello=function() return {protocol=2} end}
local battleState
package.loaded['src.link.LinkState']={new=function(game) local s={stage='menu',update=function() end,decideCompat=function(self) self.stage='battleOptions' end,startMode=function(self) self.stage='battleWait' end};battleState=s;return s end}
local Version=require('src.core.GameVersion');local oldGet=Version.get;Version.get=function() return 'red' end
local game={save=originalSave,writeSave=function() return true end,returnToLauncher=function() returned=returned+1 end,stack={push=function() end}}
Arena.queue(cup,match,'slot1');save.party[1].level=99;Arena.consume(game)
check(game.retroArena and game.save.party[1].level==5 and not game:writeSave(),'the frozen party is isolated from live saves and cannot be written as adventure progress')
battleState:sendHello(nil);check(net.hello.arena.match==matchid and net.hello.arena.account=='17','the link hello binds the expected pairing and account without sending a login token')
battleState.peerHello={arena={tournament=id,match=matchid,account='99',edition='red',team_size=3,level=50}}
battleState:decideCompat('battle',false)
check(returned==1 and game.save==originalSave and not game.retroArena and net.closed,'a wrong peer closes the room, restores the original save and returns to the launcher')
check(Arena.takeNotice().id==id,'the pairing notice follows the player back to the lobby')
Version.get=oldGet
local noop=function() end;local W=require('src.import.TournamentWorkspace')
love.keyboard={setTextInput=noop,isDown=function() return false end};love.system={getClipboardText=function() return '' end}
local UI={section='tournaments',ready={red=true},_ui={col=noop},_sbGo=function(self,id) self.section=id end}
response={account_id='17',tournaments={},manage=true,total=0}
W.tick(UI);W.tick(UI);check(UI._tournaments.index.manage,'the account-only workspace loads the tournament catalogue')
W.action(UI,'create');W.action(UI,'field:title')
check(UI._tournaments.form.title=='' and UI._tournaments.focus=='title','staff can edit a cup in the native workspace')
account='18';W.tick(UI);check(UI._tournaments.account=='18' and not UI._tournaments.form,'switching accounts destroys the previous private draft and cache')
signed=false;W.tick(UI);check(not UI._tournaments and UI.section=='games','sign-out removes the Arena view and returns to the library')
print('Tournament and Arena: '..n..' checks passed')
signed=true;account='17';UI.section='tournaments';UI._s=1
local font=love.graphics.newFont(14)
font.getWrap=function(_,text,width) return width,{text} end
UI.hintFont=font;UI.stateFont=font
UI.palette=function() return {ink={1,1,1},detail={.7,.8,.9},link={.2,.8,.9},chooseTop={1,.2,.3}} end
UI._chipButton=function(_,x,y,label,opts) return {x=x,y=y,width=opts.w,height=opts.h} end
package.loaded['src.import.LauncherLibrary']={paint={surface=noop}}
love.graphics.arc=love.graphics.arc or noop
W.tick(UI);W.tick(UI);check(W.draw(UI,0,0,640,640)>0,'the empty Arena still draws its header and staff controls')
W.action(UI,'create');check(W.draw(UI,0,0,640,640)>640,'the native creation form remains scrollable');W.action(UI,'dismiss')
UI._tournaments.cup={id=id,account_id='17',title='Fixture Cup',edition='red',generation=1,state='running',team_size=3,level=50,entries=2,capacity=8,rules='Singles',manage=true,
 players={{id='17',nickname='Fixture',ready=true},{id='18',nickname='Peer',ready=true}},matches={{id=matchid,left='17',right='18',state='disputed',round=1,can_report=true}},prize={dex=25}}
check(W.draw(UI,0,0,640,640)>0,'the bracket renders paired names, dispute actions and edition-specific prizes')
W.action(UI,'resolve:1:left');check(W.draw(UI,0,0,640,640)>0 and UI._tournaments.confirm.winner=='17','organizer decisions use an explicit winner confirmation and reason')
print('Tournament workspace rendering: 4 checks passed')
local formats={{id='rookie',title='Rising Star Cup',team_size=3,level=50,color='teal',minimum_points=0},{id='worlds',title='Best of Worlds',team_size=6,level=100,color='gold',minimum_points=1000}}
UI._tournaments.confirm=nil;UI._tournaments.cup=nil
UI._tournaments.index={account_id='17',tournaments={},total=0,arena={account_id='17',points=50,worlds_points=1000,formats=formats}}
check(W.draw(UI,0,0,900,640)>640,'the league renders selectable graphic cup cards and account points')
local rect;for _,r in ipairs(UI._tournaments.rects) do if r.id=='format:rookie' then rect=r end end
check(rect and rect.width>0 and rect.height>0,'cup cards expose native hit rectangles with the launcher width/height contract')
W.action(UI,'format:worlds');check(UI._tournaments.selected=='worlds','cup selection is independent from local saved parties')
response={account_id='17',points=50,queue={format='rookie',edition='crystal',state='searching'}}
W.action(UI,'format:rookie');W.action(UI,'findRival');W.tick(UI)
check(sent.path=='/arena/queue' and sent.payload.format=='rookie' and UI._tournaments.index.arena.queue.state=='searching','matchmaking uses the authenticated server queue rather than pairing locally')
W.action(UI,'create');W.action(UI,'preset:worlds')
-- The league response replaces the arena document; presets must come from the fresh server catalogue.
UI._tournaments.index.arena.formats=formats;W.action(UI,'preset:worlds')
check(UI._tournaments.form.team_size=='6' and UI._tournaments.form.level=='100','staff cup presets apply their team size and level')
response={account_id='18'};check(not T.arena('GET'),'league responses for another account are discarded')
print('Arena league workspace: 6 checks passed')
response={account_id='17',tournaments={},total=0,arena={points=0,worlds_points=1000,formats={
 {id='worlds',title='Best of Worlds',team_size=6,level=100,color='gold',minimum_points=1000},
 {id='kanto_boulder',title='Kanto Boulder Cup',generation=1,team_size=3,level=30,minimum_points=0},
 {id='johto_sprout',title='Johto Sprout Cup',generation=2,team_size=3,level=20,minimum_points=0}}}}
UI._tournaments.form=nil;UI._tournaments.index=response
local drawn={};local oldPrintf=love.graphics.printf;love.graphics.printf=function(t,...) drawn[#drawn+1]=t;return oldPrintf(t,...) end
W.action(UI,'arenaGeneration:1');check(W.draw(UI,0,0,320,640)>0 and UI._tournaments.selected=='kanto_boulder','a narrow layout selects a matching regional cup before the locked Worlds card')
local visible={};for _,r in ipairs(UI._tournaments.rects) do visible[r.id]=true end
check(visible['format:kanto_boulder'] and not visible['format:johto_sprout'],'generation selection excludes cups for other generations')
local editionPrinted=false;for _,t in ipairs(drawn) do if t:find('GEN 1 / RED / 3v3',1,true) then editionPrinted=true end end
check(editionPrinted,'each cup card prints its exact generation and edition')
W.action(UI,'arenaEdition:blue');check(UI._tournaments.queueEdition=='blue','the selected edition has a direct native button')
love.graphics.printf=oldPrintf
print('Regional cup catalogue: 4 checks passed')
