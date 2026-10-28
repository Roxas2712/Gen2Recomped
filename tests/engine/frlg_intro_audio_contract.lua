package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local events={};local old=package.loaded['src.core.Music']
package.loaded['src.core.Music']={stop=function()events[#events+1]='stop'end,
  play=function(_,song)events[#events+1]=song end}
package.loaded['src.ui.Gen3IntroFRLG']=nil
local Intro=require('src.ui.Gen3IntroFRLG');local pops,done=0,0
local game={data={constants={}},input={wasPressed=function()return false end},stack={pop=function()pops=pops+1 end}}
local scene=Intro.new(game,function()done=done+1 end);scene:enter()
T.eq(events[1],'stop','movie entry clears previous music')
for _=1,150 do scene:update()end
T.eq(#events,1,'studio card does not play the fight cue')
T.eq(scene.phase,'gf','studio reaches native GF opening')
for _=1,20 do scene:update()end
T.eq(events[2],'SONG_141','native GF star starts GAME_FREAK')
T.eq(#events,2,'GF star starts its cue exactly once')
scene:startScene1();scene.s1.state=3;scene.s1.fade=.1;scene.s1.fadeStep=.5
scene:stepScene1()
T.eq(events[3],'SONG_115','grass fade completion starts INTRO_FIGHT')
T.eq(scene.s1.state,4,'fight cue shares native grass state transition')
scene:stepScene1();T.eq(#events,3,'grass wait does not restart fight music')
scene:finish();scene:finish()
T.eq(events[4],'stop','leaving intro stops movie music')
T.eq(pops,1,'movie exits host stack once')
T.eq(done,1,'movie completion callback is retained')
package.loaded['src.core.Music']=old
T.finish('FRLG intro stage audio and host lifecycle')
