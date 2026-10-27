package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Game=require('src.core.Game')
local Screens=require('src.ui.Screens')
local Save=require('src.core.SaveData')
local originalGet,originalLoad=Screens.get,Save.load
local calls={new=0,continued=0,restore=0};local slot,backup={},'backup-slot'
Screens.get=function()return{new=function(game,callbacks)return callbacks end}end
Save.load=function()return slot,backup end
local game={data={},newGame=function()calls.new=calls.new+1;return 'new' end,
 continueGame=function(_,loaded,recovered)calls.continued=calls.continued+1;T.eq(loaded,slot,'title forwards loaded save');T.eq(recovered,backup,'title retains recovery marker')end,
 restoreSave=function(_,loaded,recovered)calls.restore=calls.restore+1;T.eq(loaded,slot,'native continue delegates actual slot');T.eq(recovered,backup,'native continue retains recovery marker');return 'restored' end}
local title=Game.makeTitleState(game)
title.onNewGame();T.eq(calls.new,1,'title uses observable native newGame')
title.onContinue();T.eq(calls.continued,1,'title uses observable native continueGame')
T.eq(Game.continueGame(game,slot,backup),'restored','native migration path result retained')
T.eq(calls.restore,1,'actual restore called once')
T.eq(Game.continueGame(game,nil),'new','missing slot starts a new game')
T.eq(calls.new,2,'missing slot newGame called once')
Save.load=function()return nil end;title.onContinue();T.eq(calls.continued,1,'unreadable slot does not start continue')
Screens.get,Save.load=originalGet,originalLoad
local oldNew,oldPush,oldWorld=Save.newGame,Screens.push,package.loaded['src.world.OverworldController']
local World={};package.loaded['src.world.OverworldController']=World
local created=0;local callback;local screenId='Gen3RsBirchSpeech'
Save.newGame=function()return{player={gender='boy',map='TRUCK',x=2,y=2,facing='down'},options={}}end
local stack={top=function()return nil end,clearWorld=function()end}
local fresh={data={field={boot={screens={newGame=screenId}}}},stack=stack,overworld={stale=true},
  bootConfig=function()return{}end,adoptSave=function()end,applyOptions=function()end}
stack.push=function(_,factory,map,x,y,facing)
  T.eq(factory,World,'world uses the actual factory');T.eq(map,'TRUCK','opening map retained')
  T.eq(x,2,'opening x retained');T.eq(y,2,'opening y retained');T.eq(facing,'down','opening facing retained')
  created=created+1;fresh.overworld={gender=fresh.save.player.gender}
end
Screens.push=function(g,id,done)T.eq(g,fresh,'speech receives fresh game');T.eq(id,screenId,'requested speech retained');callback=done end
Game.newGame(fresh)
T.eq(created,0,'RS world is deferred through gender/name selection')
T.eq(fresh.overworld,nil,'abandoned world is not visible during RS speech')
fresh.save.player.gender='girl';callback()
T.eq(created,1,'RS completion creates exactly one world')
T.eq(fresh.overworld.gender,'girl','world sees selected gender at construction')
screenId='BirchSpeech';fresh.data.field.boot.screens.newGame=screenId
Game.newGame(fresh);T.eq(created,2,'legacy speech keeps existing eager world contract')
callback();T.eq(created,2,'legacy completion never creates another world')
Save.newGame,Screens.push,package.loaded['src.world.OverworldController']=oldNew,oldPush,oldWorld
T.finish('native game lifecycle entry points')
