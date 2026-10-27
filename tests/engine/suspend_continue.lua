package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Game=require('src.core.Game')
local capsule={schema=1};local match=true;local restores=0;local failure=false
local loaded={version='red',meta={playthroughId='selected-normal'}};local boot={version='red',meta={}};local resumed={version='red',battle=true}
package.loaded['src.storage.SuspendStore']={has=function()return true end,read=function()return capsule end,matchesNormal=function()return match end}
package.loaded['src.core.SuspendJournal']={restore=function(game,value)
 T.check(game.save==loaded and value==capsule,'automatic resume binds to the selected normal playthrough rather than the fresh title skeleton')
 restores=restores+1;if failure then return nil,'Different engine build'end;game.save=resumed;return true
end}
local notice;package.loaded['src.ui.RetroOverlay']={open=function(game)notice=game end}
local normal=0;Game.restoreSave=function(self,save)normal=normal+1;self.save=save;return true end
Game.save=boot;T.check(Game:continueGame(loaded)and Game.save==resumed and normal==0,'continue enters the reconstructed battle directly')
failure=true;Game.save=boot;T.check(Game:continueGame(loaded)and Game.save==loaded and normal==1 and notice==Game,'incompatible suspend falls back to the normal save with a visible notice')
match=false;notice=nil;Game.save=boot;Game:continueGame(loaded)
T.check(restores==2 and Game.save==loaded and normal==2 and not notice,'normal progress newer than the capsule never automatically rewinds')
T.finish('Continue cloud suspend')
