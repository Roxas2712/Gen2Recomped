-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Native=require('src.battle.Gen3SafariText');local Profile=require('src.core.game3.battle.profile')
local Text=require('src.core.game3.rom_text');local BattleText=require('src.core.game3.battle.battle_text')
local Battle=require('src.core.game3.battle');local G=require('src.core.Game3')
local oldGame,oldVersion=package.loaded['src.core.Game'],V.get()
local oldLoad=love.filesystem.load;love.filesystem.load=loadfile
T.eq(Profile.of({}),nil);T.eq(package.loaded['src.core.Game'],oldGame,'metadata import cannot bootstrap Game')
local nativeFile=io.open('src/import/Gen3SafariAssets.lua','rb')
if nativeFile then
 nativeFile:close();local Assets=require('src.import.Gen3SafariAssets')
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
  package.loaded['src.core.Game']=game;local b=f.fresh('TACKLE').battle
  local catalog={schema=1,edition=edition,romSha1=V.info().sha1,named={},records={}}
  game.data.text_pointers={namedIR=catalog}
  local hoenn=edition~='firered'and edition~='leafgreen'
  local spec={format=1,version=edition,dialect=(edition=='ruby'or edition=='sapphire')and'rs'or hoenn and'rse'or'frlg',
   labels={'QA BALL','QA SECOND','QA THIRD','QA RUN'},textIR={}}
  for _,key in ipairs{'menu','prompt','balls','left','gotAway','wildFled','watching','used','outOfBalls','boxFull',
   'goNear','tooNear','pokeblock','curious','enthralled','ignored','rock','bait','angry','eating'}do
   spec.textIR[key]={{t='text',s='QA '..key},{t='eos'}}
  end
  if hoenn then
   spec.escapeFactor=3;spec.tables={format=1,goNearCounterToCatchFactor={4,3,2,0},goNearCounterToEscapeFactor={4,3,2,0},pkblToEscapeFactor={},flavorCompatibility={}}
   for n=0,4 do spec.tables.pkblToEscapeFactor[n]={0,1,0}end
   for n=0,124 do spec.tables.flavorCompatibility[n]=0 end
  end
  game.data.constants.gen3SafariNative=spec;T.check(Assets.valid(spec,edition))
  local profile=require('src.import.Gen3BattleTextCatalog').profile(edition)
  local playerCode;for code,name in pairs(profile.placeholders)do if name=='B_PLAYER_NAME'then playerCode=code end end
  spec.textIR.prompt={{t='ext',cmd=1,args={2}},{t='text',s='QA '},{t='bph',code=assert(playerCode)},{t='nl'},{t='text',s='prompt'},{t='eos'}}
  local hp,pp=b.player.mon.hp,b.player.curMoves[1].pp
  local count=0;b.rng=function()count=count+1;return 0 end
  T.eq(Profile.of({}),nil);b:makeSafari({balls=30,steps=400})
  game.stack:push(b);local state=assert(Battle.getState());local view=assert(Profile.of(state))
  T.eq(view.id,edition);T.eq(view.open,true);T.eq(view.rules,nil,'query does not advertise action/rule capabilities')
  local key=view.strings.safariPrompt;T.eq(Text.has(key),true)
  T.eq(BattleText.get(key),'QA PROBE\nprompt','native player placeholder keeps the edition-specific battle namespace')
  local ir=Text.ir(key);T.eq(ir[1].cmd,1);T.eq(ir[3].t,'ph');T.eq(ir[3].code,playerCode)
  ir[1].args[1]=99;T.eq(spec.textIR.prompt[1].args[1],2,'native Safari IR stays private')
  T.eq(spec.textIR.prompt[3].t,'bph','metadata cannot rewrite native interpreter operands')
  local Hud=require('src.core.game3.battle.healthbox');local Painter=require('src.battle.Gen3Battle')
  local safariPaint,statusPaint=Painter.drawSafariPanel,Painter.drawStatusPanel
  local safariCalls,statusCalls=0,0;local hx,hy=Painter.healthboxGeometry(b,0)
  Painter.drawSafariPanel=function(screen,x,y)
   T.eq(screen,b);T.eq(x,hx+3);T.eq(y,hy-2);safariCalls=safariCalls+1;return true
  end
  Painter.drawStatusPanel=function(screen,who,x,y,player)
   T.eq(screen,b);T.eq(who,b.enemy);T.eq(player,false);statusCalls=statusCalls+1;return true
  end
  T.eq(Hud.draw(0,state.player,{st=state,ox=3,oy=-2}),true)
  T.eq(safariCalls,1);T.eq(statusCalls,0,'Safari player uses the native ball counter, not a Pokemon HP panel')
  T.eq(Hud.draw(1,state.enemy,{st=state}),true);T.eq(statusCalls,1,'native opponent panel remains visible')
  Painter.drawSafariPanel,Painter.drawStatusPanel=safariPaint,statusPaint
  T.raises(function()view.strings.safariPrompt='bad'end,'read-only')
  game.data.text=game.data.text or{};game.data.text[key]='Explicit native label'
  T.eq(BattleText.get(key),'Explicit native label');game.data.text[key]=nil
  game.data._romTextGeneration=3;game.data.romText={};game.data._romTextTouched={[key]=true}
  T.eq(Text.has(key),false,'explicit prose tombstone cannot be resurrected');game.data._romTextTouched={}
  local source=Text.plain(key);game.data.strings={[source]='Translated {B_PLAYER_NAME}'}
  T.eq(BattleText.get(key),'Translated PROBE');game.data.strings=nil
  local strings=view.strings;local old=game.data;game.data={}
  T.eq(view.open,false);T.eq(strings.safariPrompt,nil);game.data=old
  catalog.romSha1='wrong';T.eq(Text.has(key),false);T.eq(view.open,false);catalog.romSha1=V.info().sha1
  T.eq(count,0);T.eq(b.player.mon.hp,hp);T.eq(b.player.curMoves[1].pp,pp)
  T.eq(b.safari.balls,30,'metadata cannot spend Safari resources')
  game.stack:pop();T.eq(view.open,false);T.eq(strings.safariPrompt,nil);T.eq(Profile.of(state),nil)
  f.close();G.release()
 end
else
 V.set('firered');package.loaded['src.core.Game']={data={constants={}}}
 T.eq(Profile.of({}),nil);T.eq(Text.has('native.safari.prompt'),false,'older native owners do not fabricate Safari metadata')
end
for _,edition in ipairs{'red','crystal','platinum','black'}do V.set(edition);T.eq(Text.has('native.safari.prompt'),false)end
package.loaded['src.core.Game']=oldGame;V.set(oldVersion);love.filesystem.load=oldLoad
T.finish('native Safari text namespace, current admission, readonly profile and resource neutrality')
