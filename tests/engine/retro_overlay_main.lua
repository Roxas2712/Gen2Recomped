-- Exercise the merged main-loop handlers without a ROM, window or game boot.
package.path='./?.lua;'..package.path
local n=0;local function check(value,why) assert(value,why);n=n+1 end
local file=assert(io.open('main.lua','rb'));local source=file:read('*a');file:close()
local chunks={}
for _,name in ipairs({'draw','touchpressed','touchmoved','touchreleased'}) do
  chunks[#chunks+1]=assert(source:match('(function love%.'..name..'%b().-)\nfunction love%.'),'missing main handler: '..name)
end
local install=assert(loadstring('return function(Game,RetroOverlay,GraphicsStack,drawSecondPanel,Importer,driverCo,autopilot) '..table.concat(chunks,'\n')..' end'))()
love={system={getOS=function() return 'Android' end}}
local calls={};local function event(name,...) calls[#calls+1]={name,...} end
local game={capturePath='driver-frame.png',draw=function() event('game') end}
for _,method in ipairs({'touchpressed','touchmoved','touchreleased'}) do game[method]=function(_,...) event(method,...) end end
local overlay={draw=function() event('overlay') end,press=function() event('overlay-press');return false end}
local graphics={drain=function() end}
install(game,overlay,graphics,function() event('second-panel') end)
love.draw()
check(calls[1][1]=='game' and calls[2][1]=='overlay','the game and native overlay share the final window frame in the correct order')
check(game.capturePath=='driver-frame.png','love.draw leaves driver capture ownership to WindowFrame in the main loop')
calls={};love.touchpressed('finger',10,20,3,4,.8)
check(calls[1][1]=='overlay-press' and calls[2][1]=='touchpressed','the overlay sees a primary touch before the game')
check(calls[2][2]=='finger' and calls[2][5]==3 and calls[2][6]==4 and calls[2][7]==.8,'the merged press retains delta and pressure for native touch and mod hooks')
calls={};love.touchmoved('finger',30,40,5,6,.9)
check(calls[1][1]=='touchmoved' and calls[1][5]==5 and calls[1][7]==.9,'touch motion keeps the full native event')
calls={};love.touchreleased('finger',50,60,7,8,.2)
check(calls[1][1]=='touchreleased' and calls[1][6]==8 and calls[1][7]==.2,'touch release keeps the full native event')
overlay.game=game;overlay.press=function() return true end;calls={}
love.touchpressed('finger',10,20,1,2,1);love.touchmoved('finger',20,20,1,2,1);love.touchreleased('finger',20,20,1,2,0)
check(#calls==0,'an open overlay owns the complete touch gesture')
overlay.game=nil
install(game,overlay,graphics,function() end,nil,{},nil);calls={};love.draw()
check(#calls==1 and calls[1][1]=='game','scripted drivers do not draw the interactive overlay')
install(game,overlay,graphics,function() end,nil,nil,{});calls={};love.draw()
check(#calls==1 and calls[1][1]=='game','autopilot captures retain their original frame content')
install(game,overlay,graphics,function() event('second-panel') end,{draw=function() event('launcher') end,touchpressed=function(_,...) event('launcher-touch',...) end});calls={}
love.draw();check(calls[1][1]=='launcher' and calls[2][1]=='second-panel','the launcher still draws its independent secondary display')
calls={};love.touchpressed('finger',1,2,3,4,.5)
check(calls[1][1]=='launcher-touch' and calls[1][7]==.5,'launcher touch forwarding also retains delta and pressure')
print('Retro overlay main integration: '..n..' checks passed')
