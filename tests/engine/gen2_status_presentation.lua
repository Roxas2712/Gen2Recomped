package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Battle=require('src.battle.BattleState')
local Pokemon=require('src.pokemon.Pokemon')
local Status=require('src.battle.Status')
local Strings=require('src.core.Strings')
local Catalog=require('src.battle.Gen2AnimCatalog')
local old=V.get()
local translation={
 ['%s\nis fast asleep!']='%s\nschlaeft tief.',
 ['%s\nis confused!']='%s\nist verwirrt.',
}
local function make(edition,format,language)
 V.set(edition)
 local data=T.fixtures.fresh();data.constants.gen=V.generation()
 data.battle_anims={gen2=true,scripts={
  [0x103]={entry=1,code={{op='delay',frames=3},{op='ret'}}},
  [0x104]={entry=1,code={{op='delay',frames=2},{op='ret'}}},
 },moveAnims={},objects={},framesets={},oam={},gfx={}}
 require('src.battle.Gen2AnimationIds').install(data.battle_anims)
 if format=='native'then
  local a=Catalog.compile(data.battle_anims,nil,edition)
  a.gen2,a.format,a.moveAnims,a.indices,a.misc=nil,nil,nil,nil,nil
  data.battle_anims=a
 end
 require('src.render.Font').load(data)
 local save=require('src.core.SaveData').newGame();save.options.textSpeed=1
 save.party={Pokemon.new(data,'FIXMON_A',30)}
 local s=Battle.newWild({data=data,save=save,stack={top=function()end},
  input={isDown=function()return true end,wasPressed=function()return true end}},'FIXMON_C',23)
 s.queue,s.current,s.waitFrames={},nil,nil
 s.introSlide,s.sendingOut,s.enemySendingOut=0,false,false
 s.showPlayerBack,s.showEnemyTrainer=false,false
 Strings.load(language=='de' and {strings=translation}or {})
 s.rolls={};s.rng=function(lo,hi)s.rolls[#s.rolls+1]={lo,hi};return hi or lo end
 return s
end
local function idle(s)
 return #s.queue==0 and not s.current and not s.animPlaying and (s.waitFrames or 0)<=0
   and not s.draining and s.nextInsert==nil
end
local function finish(s)
 local frames=0;while not idle(s)and frames<1500 do s:updateQueue();frames=frames+1 end
 T.check(frames<1500,'actual native status queue releases')
end
for _,edition in ipairs{'gold','silver','crystal'}do
 for _,format in ipairs{'flat','native'}do for _,language in ipairs{'en','de'}do
  for _,side in ipairs{'player','enemy'}do for _,kind in ipairs{'sleep','confused'}do
   local s=make(edition,format,language);local b=s[side];local target=s[side=='player'and'enemy'or'player']
   if kind=='sleep'then b.mon.status='SLP';b.sleepTurns=3 else b.confusedTurns=3 end
   local hp,pp=b.mon.hp,b.curMoves[1].pp
   local interrupted=s:statusInterrupt(b,target,b.curMoves[1])
   T.eq(interrupted,kind=='sleep','presentation preserves actual native interrupt result')
   T.eq(kind=='sleep'and b.sleepTurns or b.confusedTurns,2,'one actual native status-counter step')
   T.eq(#s.rolls,kind=='sleep'and 0 or 1,'only real confusion consumes the existing roll')
   if kind=='confused'then T.same(s.rolls[1],{0,255},'GSC native byte RNG ABI unchanged')end
   T.eq(#s.queue,2,'one status line and one real animation')
   local animation,text,index
   for i,row in ipairs(s.queue)do
    if row.anim then animation,index=row,i else text=row.text end
   end
   local expected=kind=='sleep'and 'ANIM_SLP'or 'ANIM_CONFUSED'
   T.eq(animation and animation.anim,expected,'native GSC program identity, never a Gen1 substitute')
   T.eq(animation and animation.attackerIsPlayer,side=='player','native status side owns mirroring')
   T.eq(index,kind=='sleep'and side=='player'and 1 or 2,'cartridge status text/animation ordering')
   T.check(text and text:find(language=='de'and(kind=='sleep'and'schlaeft'or'verwirrt')
     or(kind=='sleep'and'fast asleep'or'is confused'),1,true),'actual translated caption is retained')
   s.game.save.options.animations=false
   local starts=0;local start=s.animPlayer.start
   s.animPlayer.start=function(self,id,...)
    starts=starts+1;T.eq(id,expected,'scene-off still admits the actual misc-status program')
    return start(self,id,...)
   end
   local frames=0
   while not s.animPlaying and frames<1500 do s:updateQueue();frames=frames+1 end
   T.check(frames<1500,'real native interpreter starts while ordinary move animations are off')
   local runner=s.animPlayer.runtime
   T.eq(runner.frames,0,'admission invents no VM frame')
   T.eq(runner.animId,expected,'real interpreter exposes the actual status ID')
   finish(s)
   T.eq(starts,1,'status row starts exactly one interpreter')
   T.eq(runner.frames,kind=='sleep'and 4 or 5,'real native wait/ret owns duration')
   T.eq(b.mon.hp,hp,'status presentation does not change HP')
   T.eq(b.curMoves[1].pp,pp,'status presentation cannot spend PP')
   T.eq(#s.rolls,kind=='sleep'and 0 or 1,'drawing/VM/status text consume no new battle RNG')
   s.animPlayer:release()
  end end
 end end
end
-- The exact message index survives a later paralysis message. Neither the
-- animation nor interruption bookkeeping may be inferred from either text.
for _,language in ipairs{'en','de'}do
 local s=make('crystal','native',language);local b=s.player
 b.mon.status='PAR';b.confusedTurns=3;b.charging={};b.chargeReady=true;b.bideTurns=2
 local n=0;s.rng=function(lo,hi)n=n+1;return n==1 and 255 or 0 end
 local interrupted=s:statusInterrupt(b,s.enemy,b.curMoves[1])
 T.eq(interrupted,true,'actual late paralysis blocks native action')
 T.eq(n,2,'confusion and paralysis each use their existing roll once')
 T.eq(b.charging,nil,'structured paralysis reason clears native charge in every language')
 T.eq(b.bideTurns,nil,'structured paralysis reason clears native Bide')
 T.eq(#s.queue,3,'confusion caption, program and separate paralysis line')
 T.eq(s.queue[2].anim,'ANIM_CONFUSED','earlier exact confusion line owns the one animation')
 T.check(s.queue[3].text~=s.queue[1].text,'later paralysis text is not replaced by confusion caption')
 finish(s);s.animPlayer:release()
end
-- Misleading English words in another event cannot create an animation.
do
 local s=make('crystal','flat','en');local b=s.player
 s.data.statuses={SHAM={id='SHAM',beforeMovePriority=40,beforeMove=function()
  return false,{'Other event is confused!'},false,'opaque-native-reason'
 end}}
 b.mon.status='SHAM'
 local allowed,msgs,selfHit,reason,p=Status.beforeMove(b,s.rng,s)
 T.eq(allowed,false);T.eq(reason,'opaque-native-reason','existing fourth native return value is preserved')
 T.eq(p and p.kind,nil,'unrelated status supplies no invented presentation kind')
 T.eq(p and p.blockedStatus,'SHAM','actual registered blocking status remains available')
 s:sayStatusMsg(b,msgs[1])
 T.eq(#s.queue,1,'English-looking arbitrary text stays text')
 T.eq(s.queue[1].anim,nil,'no animation inferred from English text')
 s.animPlayer:release()
end
for _,mode in ipairs{'wake','snap','flinch','skip','missing'}do
 local s=make('crystal','native','de');local b=s.player
 if mode=='wake'then b.mon.status='SLP';b.sleepTurns=1
 elseif mode=='snap'then b.confusedTurns=1
 elseif mode=='flinch'then b.flinched=true
 elseif mode=='skip'then b.skipMove=true
 else b.mon.status='SLP';b.sleepTurns=3;s.data.battle_anims.scripts={}end
 s:statusInterrupt(b,s.enemy,b.curMoves[1])
 local count=0;for _,row in ipairs(s.queue)do if row.anim then count=count+1 end end
 T.eq(count,mode=='missing'and 1 or 0,mode..' has no false status program')
 finish(s);T.eq(s.animPlaying,false,mode..' releases its native queue')
 s.animPlayer:release()
end
-- Gen1/GBA callers retain their original animation names and native side rules.
for _,edition in ipairs{'red','firered','emerald'}do
 local s=make(edition,'flat','en')
 for _,side in ipairs{'player','enemy'}do for _,kind in ipairs{'sleep','confused'}do
  s.queue,s.nextInsert={},nil;s:statusOnomatopoeia(s[side],kind)
  local expected=kind=='sleep'and(side=='player'and'SLP_PLAYER_ANIM'or'SLP_ANIM')
    or(side=='player'and'CONF_PLAYER_ANIM'or'CONF_ANIM')
  for _,row in ipairs(s.queue)do if row.anim then T.eq(row.anim,expected,'non-GSC status identity unchanged')end end
 end end
end
Strings.load({});V.set(old)
T.finish('native GSC status identity, translated captions, structured causes and real queue/VM')
