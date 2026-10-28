-- Menu/view toggles consume press edges, never operating-system repeat events.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local noop=function()end
love.filesystem.read=function()return nil end;love.filesystem.write=function()return true end
love.joystick={getJoysticks=function()return{}end}
love.window.hasFocus=function()return true end
local function channel()return{clear=noop,pop=noop,push=noop,getCount=function()return 0 end}end
love.thread={getChannel=channel,newThread=function()return{start=noop,isRunning=function()return false end,getError=noop}end}
love.audio={newQueueableSource=function()return{setVolume=noop,stop=noop,isPlaying=function()return true end,getFreeBufferCount=function()return 0 end}end}
local player=require('src.pinball.Player').new({},{});local commands={}
player.command=function(_,message)commands[#commands+1]=message end
player:keypressed('escape','escape',false);assert(player.paused)
for _=1,20 do player:keypressed('escape','escape',true)end
assert(player.paused and #commands==1,'held Escape must not flash the pause overlay')
player:keypressed('escape','escape',false);assert(not player.paused)
player:keypressed('f6','f6',false);assert(player.settings.full_table)
for _=1,20 do player:keypressed('f6','f6',true)end
assert(player.settings.full_table,'held F6 must not alternate the table layout')
love.window.hasFocus=function()return false end;player:update(.016)
assert(not player.paused,'normal focus changes do not insert an automatic test pause menu')
local noticeY
love.graphics.printf=function(text,_,y)if text==player.notice then noticeY=y end end
player:draw(800,600,false)
assert(noticeY and noticeY<100,'view notice must stay above the table, away from score digits')
player:dispose();player:dispose();player:draw(800,600,false)
print('Pinball controls: repeat-safe menu/table, focus handling and final-draw lifecycle passed')
