package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local oldLoad=love.filesystem.load;love.filesystem.load=loadfile
local G=require('src.battle.Gen3Safari');local A=require('src.import.Gen3SafariAssets')
local Rules=require('src.battle.Gen3SafariRules')
local Commands=require('src.battle.BattleCommands')
for _,v in ipairs({'ruby','sapphire','emerald','firered','leafgreen'})do
  local f=require('tools.battle-source-runtime.fixture').new(v)
  local b=f.fresh('TACKLE').battle;local game=b.game
  local rse=Rules.isHoenn(v)
  local s={format=1,version=v,dialect=(v=='ruby'or v=='sapphire')and'rs'or rse and'rse'or'frlg',
    labels=rse and{'BALL','POKéBLOCK','GO NEAR','RUN'}or{'BALL','BAIT','ROCK','RUN'},textIR={}}
  for _,key in ipairs({'menu','prompt','balls','left','gotAway','wildFled','watching','used','outOfBalls','boxFull',
    'goNear','tooNear','pokeblock','curious','enthralled','ignored','rock','bait','angry','eating'})do
    s.textIR[key]={{t='text',s=key},{t='eos'}}
  end
  if rse then
    s.escapeFactor=3;s.tables={format=1,goNearCounterToCatchFactor={4,3,2,0},
      goNearCounterToEscapeFactor={4,3,2,0},pkblToEscapeFactor={},flavorCompatibility={}}
    for n=0,4 do s.tables.pkblToEscapeFactor[n]={0,1,0}end
    for n=0,124 do s.tables.flavorCompatibility[n]=0 end
  end
  game.data.constants.gen3SafariNative=s
  T.check(A.valid(s,v));local sf={balls=30,steps=500};b:makeSafari(sf)
  T.eq(b.safari,sf);T.eq(b.gen3Safari.edition,v)
  T.same(G.actions(b),rse and{'ball','pokeblock','go_near','run'}or{'ball','bait','rock','run'})
  local draws={};b.rng=function(lo,hi)T.eq(lo,0);T.eq(hi,65535);draws[#draws+1]=1;return 99 end
  game.stack:push(b);b.queue={};b.phase='menu'
  T.eq(Commands.reason(b,{kind='safari',action=rse and'bait'or'go_near'}),'action is unavailable in this Safari edition')
  T.eq(b:chooseSafari(rse and'rock'or'pokeblock'),false);T.eq(#draws,0)
  if rse then
    local P=require('src.inventory.Pokeblocks')
    local block={flavours={10,0,0,0,0},feel=20,colour=1};P.case(game.save)[7]=block
    b:chooseSafari('pokeblock');local picker=game.stack:top()
    T.check(picker~=b);T.eq(b.waitingUI,true);T.eq(#draws,0);T.eq(P.case(game.save)[7],block)
    picker:close();T.eq(game.stack:top(),b);T.eq(b.phase,'menu');T.eq(b.waitingUI,nil);T.eq(#draws,0)
    b:chooseSafari('pokeblock');picker=game.stack:top();picker:choose()
    T.eq(game.stack:top(),b);T.eq(P.case(game.save)[7],nil);T.eq(#draws,1)
    T.eq(b.gen3Safari.pokeblockThrows,1);T.eq(sf.balls,30)
    local count=#b.queue;picker.onPick(7,block);T.eq(#b.queue,count,'confirmation callback is single-use')
    b.queue={};b.phase='menu';local old=b.gen3Safari.escapeFactor
    b:chooseSafari('go_near');T.eq(b.menuIndex,3);T.eq(b.gen3Safari.escapeFactor,old+4)
    T.eq(#draws,2);T.eq(sf.balls,30)
    -- The flee decision was made at the old 15%, not the new 35%.
    b.rng=function()return 20 end;b.queue={};b.phase='menu';b.gen3Safari.escapeFactor=3
    b:chooseSafari('go_near');b.nextInsert=0;b.queue[#b.queue].fn();b.nextInsert=nil;T.eq(b.result,nil)
    T.eq(b.queue[1].text,'watching')
  else
    b:chooseSafari('bait');T.eq(#draws,2,'flee selection and bait timer each draw once')
    T.eq(b.gen3Safari.baitCounter,6);T.eq(b.gen3Safari.rockCounter,0)
    b.nextInsert=0;b.queue[#b.queue].fn();b.nextInsert=nil;T.eq(b.gen3Safari.baitCounter,5);T.eq(b.queue[1].text,'eating')
    b.phase='menu';b.queue={};b:chooseSafari('rock');T.eq(b.gen3Safari.baitCounter,0)
    T.eq(b.gen3Safari.rockCounter,6)
  end
  -- Ball uses ordinary public catch/storage seams and original factor.
  b.phase='menu';b.queue={};b.gen3Safari.escapeFactor=2;b.rng=function()return 99 end
  local rate;function b:catchAttempt(ball,value)T.eq(ball,'SAFARI_BALL');rate=value;return false,0 end
  function b:ballChain()end;function b:ballMissMessage()return'missed'end
  b:chooseSafari('ball');T.eq(sf.balls,29);T.eq(b.queue[1].text,'used')
  b.nextInsert=0;b.queue[2].fn();b.nextInsert=nil;T.eq(rate,b.safariCatchRate);T.eq(b.lastBall,'SAFARI_BALL')
  sf.balls=0;b.queue={};G.enemyTurn(b,false);T.eq(b.result,'run');T.eq(b.afterQueue,'finish')
  T.eq(b.queue[1].text,'outOfBalls','last missed ball ends before another flee/reaction')
  b.result=nil;sf.balls=10;b.queue={};b.phase='menu'
  b:chooseSafari('run');T.eq(sf.balls,10);T.eq(b.result,'run');T.eq(b.queue[1].text,'gotAway')
  f.close()
end
love.filesystem.load=oldLoad
T.finish('Native GBA Safari commands, action timing, selector cancellation and shared catch seam')
