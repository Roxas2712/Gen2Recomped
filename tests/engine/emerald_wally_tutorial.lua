package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local A=require('src.import.Gen3EmeraldWallyAssets')
local Writer=require('src.import.LuaWriter')
local function copy(t)if type(t)~='table'then return t end;local n={};for k,v in pairs(t)do n[k]=copy(v)end;return n end
local spec={format=1,version='emerald',game='emerald',romSha1='f3ae088181bf583e55daf962a92bb46f4f1d07b7',
 dialect='rse',backIndex=6,manifest=A.ROOT..'manifest.lua',resources=A.resources(),
 images={idle=A.ROOT..'idle.png',strip=A.ROOT..'strip.png'},anim={rest=3,throw={{0,24},{1,9},{2,24},{0,9},{3,50}}},textIR={}}
for key in pairs(A.labels)do spec.textIR[key]={{t='text',s='ROM_'..key}}end
spec.textIR.BattleText_TutorialUsed={{t='bph',code=0x16}}
spec.textIR.BattleText_BallCaught2={{t='bph',code=6}}
spec.textIR.BattleText_ComeBackSingle1={{t='bph',code=0}}
T.check(A.valid(spec,'emerald'),'complete own Emerald tutorial resources')
for _,v in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do T.check(not A.valid(spec,v),'no cross-edition tutorial resources')end
for _,change in ipairs{'digest','index','rest','frame','duration','label','path','resource','version','format'}do
 local s=copy(spec)
 if change=='digest'then s.romSha1=string.rep('a',40)
 elseif change=='index'then s.backIndex=2
 elseif change=='rest'then s.anim.rest=0
 elseif change=='frame'then s.anim.throw[1][1]=4
 elseif change=='duration'then s.anim.throw[1][2]=0
 elseif change=='label'then s.textIR.BattleText_WallyBall=nil
 elseif change=='path'then s.images.idle='ruby/idle.png'
 elseif change=='resource'then s.resources[2]='foreign.png'
 elseif change=='version'then s.version='sapphire'
 elseif change=='format'then s.format=0 end
 T.check(not A.valid(s,'emerald'),'reject incomplete/foreign '..change)
end
local Fs=require('src.import.CacheFs');local read,exists=Fs.read,Fs.exists
local bodies={};local function ready()
 local manifest=copy(spec);manifest.files={spec.images.idle,spec.images.strip}
 bodies['data/generated/constants.lua']=Writer.encode({gen3EmeraldWally=spec})
 bodies[spec.manifest]=Writer.encode(manifest);bodies[spec.images.idle]='image';bodies[spec.images.strip]='image'
end
Fs.read=function(p)return bodies[p]end;Fs.exists=function(p)return bodies[p]~=nil end;ready()
T.eq(#A.missing('emerald'),0,'complete original cache is ready')
bodies[spec.images.strip]=nil;T.eq(A.missing('emerald')[1],spec.images.strip,'missing throw frames invalidate cache')
ready();bodies[spec.manifest]='return {}';T.eq(A.missing('emerald')[1],'<emerald:wally-manifest>','manifest cannot be replaced by an empty cache')
ready();bodies['data/generated/constants.lua']='error("untrusted cache")'
T.eq(A.missing('emerald')[1],'<emerald:original-wally-tutorial>','corrupt constants fail closed')
for _,v in ipairs{'ruby','sapphire','firered','leafgreen'}do T.eq(#A.missing(v),0,'other editions keep their own readiness')end
Fs.read,Fs.exists=read,exists

local version='emerald';local oldV=package.loaded['src.core.GameVersion']
package.loaded['src.core.GameVersion']={get=function()return version end}
local oldLove=love;love=love or{};love.filesystem=love.filesystem or{}
local oldLoad=love.filesystem.load;love.filesystem.load=function(path)return assert(loadfile(path))end
local Controller=require('src.battle.Gen3RsWallyTutorial')
local battle={data={constants={gen3EmeraldWally=spec},items={POKE_BALL={name='ROM_BALL'}}},
 player={mon={species='ZIGZAGOON',level=7,hp=20},name='ROM_ZIG',def={abilities={'PICKUP','NONE'}},curMoves={{pp=35}}},
 enemy={mon={hp=18},name='ROM_RALTS'},demoName='ROM_WALLY',phase='menu',frame=0,queue={},moves={}}
function battle:chooseMenu(kind)T.eq(kind,'fight');self.phase='moveSelect'end
function battle:chooseMove(slot)self.moves[#self.moves+1]=slot;self.player.curMoves[slot].pp=self.player.curMoves[slot].pp-1;self.enemy.mon.hp=self.enemy.mon.hp-6;self.phase='messages'end
function battle:say(text)self.queue[#self.queue+1]={text=text}end
function battle:act(fn)self.queue[#self.queue+1]={action=fn}end
local w=assert(Controller.new(battle))
T.eq(battle.demoName,'ROM_WALLY','keep own trainer-table name')
T.eq(battle.demoBackPath,spec.images.idle,'own Emerald Wally pose')
T.eq(battle.player.abilityOverride,false,'borrowed Zigzagoon selects original empty second ability')
T.eq(w:text('BattleText_WallyMenu'),'ROM_BattleText_WallyMenu','own Emerald prompt IR')
T.eq(w:text('BattleText_TutorialUsed'),'ROM_BALL','Emerald B_LAST_ITEM uses its own code22')
T.eq(w:text('BattleText_BallCaught2'),'ROM_RALTS','Emerald opponent placeholder uses code6')
T.eq(w:text('BattleText_ComeBackSingle1'),'ROM_ZIG','recall buffer identifies the borrowed Pokemon')
for turn=1,2 do
 for tick=1,144 do battle.frame=battle.frame+1;w:updateMenu()end
 T.eq(#battle.moves,turn,'one original move after the 64+80 frame choice')
 T.eq(battle.moves[turn],1,'first borrowed move is selected without player input')
 battle.phase='menu'
end
T.eq(battle.player.curMoves[1].pp,33,'two real move selections spend two PP')
T.eq(w.state.wallyState,2,'recall follows both original turns')
for tick=1,64 do battle.frame=battle.frame+1;w:updateMenu()end
T.eq(w.state.wallyState,3,'third original action is the recall/throw sequence')
T.eq(#battle.moves,2,'recall never selects a third attack')
local waits={};for _,entry in ipairs(battle.queue)do if entry.wait then waits[#waits+1]=entry.wait end end
T.eq(waits[1],10,'recall wait plus native queue dispatch makes twelve frames')
T.eq(waits[2],46,'trainer-return wait plus dispatch makes forty-eight frames')
T.eq(battle.queue[1].text,'ROM_BattleText_ComeBackSingle3','recall chooses own damage-dependent text')
local rs=copy(spec);rs.textIR.BattleText_Wally={{t='text',s='ROM_RS_WALLY'}}
rs.images={idle='rs-idle',strip='rs-strip'};rs.dialect=nil;rs.version='ruby'
rs.textIR.BattleText_TutorialUsed={{t='bph',code=0x13}}
rs.textIR.BattleText_BallCaught2={{t='bph',code=3}}
version='ruby';battle.data.constants.gen3RsWally=rs
local rw=assert(Controller.new(battle));T.check(rw~=nil,'Ruby native controller retained')
T.eq(battle.demoName,'ROM_RS_WALLY','RS still uses its own original label')
T.eq(rw:text('BattleText_TutorialUsed'),'ROM_BALL','Ruby item placeholder stays code19')
T.eq(rw:text('BattleText_BallCaught2'),'ROM_RALTS','Ruby opponent placeholder stays code3')
version='sapphire';rs.version='sapphire';rw=assert(Controller.new(battle))
T.eq(rw:text('BattleText_TutorialUsed'),'ROM_BALL','Sapphire item placeholder stays code19')
T.eq(rw:text('BattleText_BallCaught2'),'ROM_RALTS','Sapphire opponent placeholder stays code3')
for _,v in ipairs{'firered','leafgreen','gold','black'}do version=v;T.eq(Controller.new(battle),nil,'unrelated catching demos unchanged')end

version='emerald'
local oldBag,oldItem,oldSound=package.loaded['src.ui.Gen3BagMenu'],package.loaded['src.ui.Gen3ItemMenu'],package.loaded['src.core.Sound']
package.loaded['src.core.Sound']={play=function()end}
local stack={};local game={data={constants={gen3ItemMenu={labels={'ROM_USE',nil,nil,nil,'ROM_CANCEL'},cancel=5}},
 items={POTION={name='ROM_POTION'},POKE_BALL={name='ROM_BALL'}}},
 save={inventory={POTION=9,POKE_BALL=8},player={name='PLAYER',gender='girl'}},stack={}}
function game.stack:push(s)stack[#stack+1]=s end
function game.stack:pop()return table.remove(stack)end
function game.stack:top()return stack[#stack]end
package.loaded['src.ui.Gen3BagMenu']={new=function(g,opts)
 local bag={game=g,emerald=true,pocket=1,lockPocket=opts.pocket~=nil,noInput=opts.noInput,wallyTutorial=opts.wallyTutorial,
  scriptRows=opts.rows,rows=opts.rows,script=opts.script}
 function bag:movePocket(dir)if self.lockPocket then return end;self.pocket=self.pocket+dir;self.rows=self.scriptRows end
 return bag
end}
package.loaded['src.ui.Gen3ItemMenu']={new=function(g,opts)
 local popup=opts
 function popup:close(kind)g.stack:pop();opts.onPick(kind)end
 return popup
end}
local demo={game=game,frame=0,events={}}
function demo:ui(fn)game.stack:push(fn())end
function demo:oldManThrow()self.thrown=true end
local flow={battle=demo,events={},record=function(self,kind)self.events[kind]=self.bagTicks end}
require('src.battle.Gen3EmeraldWallyBag').open(flow)
local bag=game.stack:top();T.check(bag.noInput and bag.wallyTutorial,'original tutorial owns the pad and its male bag')
T.eq(bag.lockPocket,false,'scripted switch releases the initial-picker pocket lock')
T.eq(bag.rows[1].id,'POTION','original tutorial opens on Potion')
T.eq(bag.rows[1].qty,1,'virtual tutorial quantity')
T.check(#bag.rows==2 and bag.rows[2].close,'original CLOSE BAG row stays visible with input disabled')
local Transition=require('src.ui.Gen3EmeraldBagTransition')
local frames=0;local useSeen=false
while not demo.thrown and frames<800 do
 frames=frames+1;local top=game.stack:top()
 if top==bag then if not Transition.update(bag)and bag.script then bag.script(bag)end
 else
  if not useSeen then
   useSeen=true;T.check(top.noInput and top.emeraldBag==bag and top.columns==1,'actual native Emerald item-action presenter')
   T.eq(top.entries[1].label,'ROM_USE','own USE label');T.eq(top.entries[2].label,'ROM_CANCEL','own CANCEL label')
  end
  top.script(top)
 end
end
T.check(demo.thrown and useSeen,'scripted bag and USE finish without player input')
T.eq(flow.events['bag-pocket-switch'],102,'first original bag delay')
T.eq(flow.events['bag-use-menu'],204,'second original bag delay')
T.eq(flow.events['bag-use'],306,'third original bag delay')
T.eq(bag.pocket,2,'native rightward pocket switch reaches balls')
T.eq(bag.rows[1].id,'POKE_BALL','virtual ball row')
T.check(#bag.rows==2 and bag.rows[2].close,'ball pocket retains original CLOSE BAG row')
T.eq(game.save.inventory.POTION,9,'original Potion inventory unchanged')
T.eq(game.save.inventory.POKE_BALL,8,'original ball inventory unchanged')
T.eq(game.save.player.gender,'girl','tutorial does not rewrite player gender')
T.eq(game.save.player.name,'PLAYER','bag does not rewrite player name')
T.eq(#stack,0,'bag and action screen both return to battle')
T.check(frames>306+17+15,'native pocket/open/close transitions stay in the timeline')
package.loaded['src.ui.Gen3BagMenu'],package.loaded['src.ui.Gen3ItemMenu'],package.loaded['src.core.Sound']=oldBag,oldItem,oldSound
package.loaded['src.core.GameVersion']=oldV;love.filesystem.load=oldLoad;love=oldLove
T.finish('Original Emerald Wally: two moves, own resources and non-mutating scripted bag')
