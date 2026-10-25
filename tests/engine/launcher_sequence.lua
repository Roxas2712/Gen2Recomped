-- The animation must never boot early, twice, or after cancellation.
package.path = './?.lua;' .. package.path
love = require('tests.love_stub')
local Sequence = require('src.import.LauncherSequence')
local Library = require('src.import.LauncherLibrary')
local checks = 0
local function check(value, message) assert(value, message); checks=checks+1 end
local RI = {_ui={}}
RI.__index=RI
function RI.new(opts)
  return setmetatable({launcher=true,sidebarMode=true,ready={crystal=true},opts=opts or {},boots=0,updates=0,clicks=0},RI)
end
function RI:_settings() return self.opts end
function RI:play(v) self.boots=self.boots+1;self.bootVersion=v;self._handedOff=true end
function RI:update() self.updates=self.updates+1 end
function RI:draw() end
function RI:_settingsRows() return {} end
function RI:mousepressed() self.clicks=self.clicks+1 end
function RI:keypressed() self.clicks=self.clicks+1 end
function RI:touchpressed() self.clicks=self.clicks+1 end
function RI:wheelmoved() self.clicks=self.clicks+1 end
Sequence.install(RI)

local ui=RI.new()
check(ui._launcherSequence.kind=='intro','fresh launch has its own intro')
ui:keypressed('space');check(ui.clicks==0,'skip cannot activate a hidden control')
ui:update(0.01);check(not ui._launcherSequence and ui.boots==0,'intro skip returns to the library')
ui:mousepressed();check(ui.clicks==0,'synthesized duplicate of skip is swallowed')
ui:update(0.2);ui:mousepressed();check(ui.clicks==1,'normal controls resume after skip')

ui:play('red');check(not ui._launcherSequence,'missing ROM cannot start an animation')
ui:play('crystal');check(ui.boots==0,'starting insertion does not boot synchronously')
ui:play('crystal');check(ui.boots==0,'double play cannot start another boot')
ui:wheelmoved();check(ui.clicks==1,'the hidden page cannot scroll during insertion')
ui:update(0.5);check(ui.boots==0,'partly inserted cartridge cannot boot')
ui:update(2.0);check(ui.boots==1 and ui.bootVersion=='crystal','completed insertion boots the selected cartridge')
ui:update(2);ui:play('crystal');check(ui.boots==1,'handoff is exactly once')

ui=RI.new();ui._launcherSequence=nil;ui:play('crystal');ui:keypressed('escape');ui:update(0.1)
check(ui.boots==0 and not ui._launcherSequence,'escape cancels without booting')
ui:update(0.2);ui:play('crystal');ui:keypressed('return');ui:update(0.01)
check(ui.boots==1,'skip insertion commits on the next update')

ui=RI.new({launcherAnimations=false})
check(not ui._launcherSequence,'animations can be disabled')
ui:play('crystal');check(ui.boots==1,'disabling animations keeps immediate play')
ui=RI.new();ui._launcherSequence=nil;ui.workState='working';ui:play('crystal')
check(not ui._launcherSequence and ui.boots==0,'imports cannot be interrupted by an animated launch')
ui.workState=nil;ui.sidebarMode=false;ui:play('crystal')
check(ui.boots==1,'classic layout retains direct play')

ui=RI.new();ui.settingsPage='launcher'
local entry=ui:_settingsRows()[1]
check(entry.kind=='option' and entry.scope=='launcher' and entry.row.id=='launcherAnimations',
  'animation preference uses the launcher option dispatcher')

for _,width in ipairs({140,300,480,800,1440}) do
  for _,scale in ipairs({0.7,1,1.6}) do
    local cols,cw,ch,gap=Library.grid(width,scale)
    check(cols>=1 and cw>0 and ch>0 and cols*cw+(cols-1)*gap<=width+0.001,
      'cartridge grid fits every tested viewport')
  end
end
local state=Sequence.new('play','crystal')
local before=Sequence.insertion(state)
Sequence.advance(state,0.5);local middle=Sequence.insertion(state)
Sequence.advance(state,100)
check(before==0 and middle>before and Sequence.insertion(state)==1,'insertion reaches its slot monotonically')
local motion=Sequence.new('play','crystal')
motion.elapsed=motion.duration*0.43
local p,aligned,descent=Sequence.motion(motion)
check(aligned==1 and descent>0 and descent<1,'final insertion is straight with rotation already settled')
motion.elapsed=motion.duration*0.50
check(Sequence.insertion(motion)==1,'cartridge locks before screen/logo effects begin')
local previousAudio=love.audio
local latchPlays=0
love.audio={newSource=function(path)
  return {setVolume=function() end,stop=function() end,play=function()
    if path:find('cartridge_latch',1,true) then latchPlays=latchPlays+1 end
  end}
end}
ui=RI.new();ui._launcherSequence=nil;ui:play('crystal');ui:update(1.3)
check(latchPlays==1 and ui.boots==0,'mechanical click occurs after insertion and before handoff')
ui:update(0.2);check(latchPlays==1,'the latch click cannot repeat on subsequent frames')
ui:keypressed('escape');ui:update(0)
check(ui.boots==0,'the post-latch logo reveal can still be cancelled')
love.audio=previousAudio
local Workspace=require('src.import.LauncherWorkspace')
local settingsRows={
  {kind='section',label='CLOUD SAVES'},
  {kind='option',scope='launcher',row={id='cloudService'}},
  {kind='option',scope='launcher',row={id='cloudFolder'}},
  {kind='action',action='sbCloudSyncAll'},
  {kind='section',label='GAME DEFAULTS'},
  {kind='option',scope='settingsGen',row={id='settingsGen'}},
  {kind='option',scope='game',row={id='musicVol'}},
  {kind='section',label='TOUCH CONTROLS'},
  {kind='option',scope='touch',row={id='touchEnabled'}},
}
local cloud=Workspace.filterRows(settingsRows,'cloud')
check(#cloud==4 and cloud[4].action=='sbCloudSyncAll','cloud category retains every row and action')
local game=Workspace.filterRows(settingsRows,'game')
check(#game==3 and game[2].scope=='settingsGen','game category keeps generation selection with its options')
local controls=Workspace.filterRows(settingsRows,'controls')
check(#controls==2 and controls[2].scope=='touch','controls category does not mix game and launcher preferences')
check(Workspace.filterRows(settingsRows,'all')==settingsRows,'all settings remains an unfiltered escape hatch')
print('Launcher sequence: '..checks..' checks passed')
