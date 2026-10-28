-- Lifecycle regression: visible cartridge -> full intro -> one embedded player.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local Json=require('src.link.Json')
local realOpen=io.open
io.open=function(path,...)
 if path:sub(1,16)=='/synthetic-root/'then return {read=function()return '{}'end,write=function()end,close=function()end}end
 return realOpen(path,...)
end
love.filesystem.getSource=function()return '/synthetic-root'end
local scenes={}
love.filesystem.load=function()
 return function()return {new=function()
  local scene={duration=13.1,plays=0,releases=0}
  function scene:draw()end
  function scene:play()self.plays=self.plays+1 end
  function scene:release()self.releases=self.releases+1 end
  scenes[#scenes+1]=scene;return scene
 end}end
end
love.window.hasFocus=function()return true end;love.window.isVisible=function()return true end
local pending
love.thread={getChannel=function()return {pop=function()local p=pending;pending=nil;return p end,clear=function()end}end}
package.loaded['src.import.LauncherBackdrop']={setPaused=function()end}
local players={}
package.loaded['src.import.PokemonXYNative']={new=function(session,mode)
 local player={session=session,mode=mode,thread={isRunning=function()return true end}}
 function player:update()end;function player:draw()end;function player:keypressed()self.keys=(self.keys or 0)+1 end
 players[#players+1]=player;return player
end}
local RI={_ui={}};RI.__index=RI
function RI.new(opts)return setmetatable({launcher=true,sidebarMode=true,ready={},opts=opts or {},boots=0},RI)end
function RI:_settings()return self.opts end
function RI:play()self.boots=self.boots+1 end
function RI:update()end;function RI:draw()end;function RI:_settingsRows()return {}end
for _,method in ipairs{'keypressed','mousepressed','touchpressed','wheelmoved','gamepadpressed','joystickpressed'}do RI[method]=function()end end
local Sequence=require('src.import.LauncherSequence');Sequence.install(RI)
require('src.import.LauncherPokemonXY').install(RI)
local function prepare(ui)
 if ui._xyIntro then ui:draw();ui:update(0);for _=1,4 do ui:update(.1)end;ui:keypressed('space')end
 ui._xyEdition='y';ui._xyOpen=true;ui._xyJob={getError=function()end}
 pending=Json.encode{ok=true,data={},session={edition='y',root='/synthetic-root',data='/qa/profile',settings={},resolution=3,profile_key='current'},mode='playing'}
 -- Simulate the measured gate completing, rather than bypassing its decision.
 ui:update(0)
 local gate=players[#players];gate.closed=true;gate.thread.isRunning=function()return false end;gate.dispose=function()end
 gate.result={status='startup_pass',can_play=true,resolution=3,measured_fps=100,p95_ms=10};ui:update(0)
end
local ui=RI.new();prepare(ui)
check(ui._launcherSequence and ui._launcherSequence.kind=='play'and not ui._xyIntro,'cartridge comes before the branded intro')
ui:update(100)
check(ui._xyIntro and not ui._xyPlayer and not ui._launcherSequence,'cartridge completion starts full intro before game')
local intro=ui._xyIntro.scene
ui:draw();ui:update(0)
check(intro.plays==1,'full soundtrack starts once after the first visible frame')
for _=1,130 do ui:update(.1)end
check(not ui._xyPlayer,'game waits for the full thirteen-second intro')
ui:update(.1);ui:update(.1)
check(ui._xyPlayer and ui._xyPlayer.mode=='playing'and intro.releases==1,'completed intro releases assets and enters embedded game once')
local count=#players;ui:update(1);check(#players==count and ui.boots==0,'same-window handoff does not boot native Lua game or duplicate player')
ui=RI.new();prepare(ui);ui:update(100);ui:draw();ui:update(0);for _=1,4 do ui:update(.1)end;ui:keypressed('space')
check(ui._xyPlayer and (ui._xyPlayer.keys or 0)==0,'intro skip input never reaches the new game')
ui=RI.new({launcherAnimations=false});prepare(ui)
check(ui._xyPlayer and not ui._xyIntro and not ui._launcherSequence,'user animation preference still permits direct play')
local withAssets=io.open
io.open=function(path,...)if path:find('/intro-assets/',1,true)then return nil end;return withAssets(path,...)end
ui=RI.new();prepare(ui);ui:update(100)
check(ui._xyPlayer and not ui._xyIntro,'an installed intro script without its private artwork cannot block the game handoff')
io.open=withAssets
print('3DS presentation lifecycle: '..checks..' checks passed')
