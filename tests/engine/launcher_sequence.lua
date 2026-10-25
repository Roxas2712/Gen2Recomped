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
ui._launcherSequence.presented=true;ui:update(0)
ui:keypressed('space');check(ui.clicks==0,'skip cannot activate a hidden control')
ui:update(0.01);check(not ui._launcherSequence and ui.boots==0,'intro skip returns to the library')
ui:mousepressed();check(ui.clicks==0,'synthesized duplicate of skip is swallowed')
ui:update(0.2);ui:mousepressed();check(ui.clicks==1,'normal controls resume after skip')

ui:play('red');check(not ui._launcherSequence,'missing ROM cannot start an animation')
ui:play('crystal');check(ui.boots==0,'starting insertion does not boot synchronously')
ui:play('crystal');check(ui.boots==0,'double play cannot start another boot')
ui:wheelmoved();check(ui.clicks==1,'the hidden page cannot scroll during insertion')
ui:update(0.5);check(ui.boots==0,'partly inserted cartridge cannot boot')
ui:update(2.0);check(ui.boots==0,'device sound and logo precede the camera handoff')
ui:update(Sequence.PLAY_DURATION);check(ui.boots==1 and ui.bootVersion=='crystal','completed camera travel boots the selected cartridge')
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
motion.elapsed=Sequence.LATCH_AT*0.90
local p,aligned,descent=Sequence.motion(motion)
check(aligned==1 and descent>0 and descent<1,'final insertion is straight with rotation already settled')
motion.elapsed=motion.duration*0.50
check(Sequence.insertion(motion)==1,'cartridge locks before screen/logo effects begin')
local previousAudio=love.audio
local latchPlays,powerPlays,stops=0,0,0
local audioOrder={}
love.audio={newSource=function(path)
  return {setVolume=function() end,stop=function() stops=stops+1 end,play=function()
    audioOrder[#audioOrder+1]=path
    if path:find('cartridge_latch',1,true) then latchPlays=latchPlays+1 end
    if path:find('power_',1,true) then powerPlays=powerPlays+1 end
  end}
end}
ui=RI.new();ui._launcherSequence=nil;ui:play('crystal');ui:update(Sequence.LATCH_AT)
check(latchPlays==1 and ui.boots==0,'mechanical click occurs after insertion and before handoff')
check(powerPlays==0 and not Sequence.stages(ui._launcherSequence).powered,'latch occurs before the light and power sound')
ui:update(Sequence.POWER_AT-Sequence.LATCH_AT)
check(latchPlays==1 and powerPlays==1,'power cue follows the latch exactly once')
check(audioOrder[2]:find('power_gbc.wav',1,true),'selected hardware determines the power cue')
local stages=Sequence.stages(ui._launcherSequence)
check(stages.powered and stages.logo==0 and stages.zoom==0,'power light precedes the screen logo and camera')
ui:update(0.95)
check(Sequence.stages(ui._launcherSequence).logo==0,'power cue completes before logo formation')
ui:update(Sequence.ZOOM_AT-ui._launcherSequence.elapsed)
stages=Sequence.stages(ui._launcherSequence)
check(stages.logo==1 and stages.zoom==0,'screen logo completes before camera travel starts')
ui:update(0.5)
check(Sequence.stages(ui._launcherSequence).zoom>0 and ui.boots==0,'camera travels before the game handoff')
check(latchPlays==1 and powerPlays==1,'sounds cannot repeat during the camera move')
ui:keypressed('escape');ui:update(0)
check(ui.boots==0,'the post-latch logo reveal can still be cancelled')
check(stops==2,'cancelling stops latch and device audio sources')
ui=RI.new();ui:update(Sequence.LATCH_AT+0.1)
check(latchPlays==1 and powerPlays==1 and Sequence.insertion(ui._launcherSequence)==0,
  'application intro never inserts a cartridge or plays device sounds')
local Hardware=require('src.import.LauncherHardware')
for _,entry in ipairs({{'red',160,144,1},{'crystal',160,144,1},{'emerald',240,160,1},{'heartgold',256,192,2}}) do
  local rw,rh,screens=Hardware.nativeResolution(entry[1])
  check(rw==entry[2] and rh==entry[3] and screens==entry[4],'resolution readout follows the selected hardware')
end
love.audio=previousAudio
local oldFocus,oldVisible=love.window.hasFocus,love.window.isVisible
local focused=false
love.window.hasFocus=function() return focused end
love.window.isVisible=function() return true end
ui=RI.new()
ui:update(30)
check(ui._launcherSequence.elapsed==0 and not ui._launcherSequence.soundStarted,
  'background startup cannot consume the intro or its audio')
ui:mousepressed()
check(ui._launcherSequence.elapsed==0,'the activating click cannot skip an unseen intro')
ui._launcherSequence.presented=true;ui:update(30)
check(ui._launcherSequence.elapsed==0,'a rendered but unfocused window still waits')
focused=true;ui:update(30)
check(ui._launcherSequence.elapsed==0 and ui._launcherSequence.soundStarted,
  'focus begins the intro at time zero even after a long background wait')
ui:update(.1)
check(math.abs(ui._launcherSequence.elapsed-.1)<.001,'visible startup proceeds normally')
love.window.hasFocus, love.window.isVisible=oldFocus,oldVisible
local clock=0
local oldAudio=love.audio
love.audio={newSource=function()
  return {setVolume=function() end,play=function() end,stop=function() end,
    isPlaying=function() return true end,tell=function() return clock end}
end}
ui=RI.new();ui._launcherSequence.presented=true;ui:update(0)
clock=require('src.import.LauncherIntroScore').logoLock;ui:update(.01)
check(ui._launcherSequence.elapsed==clock,'intro choreography follows the audible sample clock')
ui:keypressed('space');ui:update(0)
check(not ui._launcherSequence,'sample-clock synchronization cannot resurrect a skipped intro')
love.audio=oldAudio
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
