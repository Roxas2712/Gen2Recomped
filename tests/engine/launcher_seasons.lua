-- CPU-only checks: calendar boundaries, seasonal flight and legacy preferences.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local Seasons=require('src.import.LauncherSeasons')
local Score=require('src.import.LauncherIntroScore')
local GenOptions=require('src.core.GenOptions')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
for month,expected in ipairs({'winter','winter','spring','spring','spring','summer','summer','summer','autumn','autumn','autumn','winter'}) do
  check(Seasons.resolve('auto',month)==expected,'calendar follows all twelve month boundaries')
end
for _,kind in ipairs({'spring','summer','autumn','winter'}) do
  check(Seasons.resolve(kind,1)==kind,'manual season overrides the calendar')
  local endPose=Seasons.pose(kind,Score.duration,720,420,1.4)
  check(endPose.logoX==720 and endPose.logoY==420 and endPose.logoScale==1 and endPose.alpha==0,
    'mascot clears the scene and wordmark settles before header docking')
  local first=Seasons.pose(kind,0,720,420,1.4)
  check(first.logoAlpha==0 and first.alpha==0,'the intro starts cleanly without an early logo flash')
  for _,size in ipairs({{480,860},{800,360},{1440,960}}) do
    local scale=math.min(size[1]/680,size[2]/640,1.4)
    local release=Seasons.pose(kind,5,size[1]/2,size[2]*.44,scale).release
    local pose=Seasons.pose(kind,release+2.1,size[1]/2,size[2]*.44,scale)
    check(pose.logoX==size[1]/2 and math.abs(pose.logoY-size[2]*.44)<.001,
      'logo reaches the visible center at narrow, short and desktop sizes')
  end
end
check(Seasons.resolve('lightning',10)=='lightning','plain lightning remains selectable')
local winterEntry=Seasons.pose('winter',.5,720,420,1)
local winterStop=Seasons.pose('winter',2.6,720,420,1)
check(winterEntry.x<winterStop.x and winterEntry.bodyRotation<winterStop.bodyRotation,
  'winter slides into position and straightens before reaching for the sack')
check(Seasons.pose('winter',3.79,720,420,1).logoAlpha==0 and Seasons.pose('winter',4.2,720,420,1).logoAlpha>0,
  'the winter logo stays in the sack until the throwing cue')
check(Seasons.pose('summer',5,720,420,1).alpha==0,'summer uses sparks without the removed dragon')
check(Seasons.resolve('obsolete',12)=='winter','unknown saved themes fall back to the calendar')
check(Score.closing[1].at==Score.catch and Score.closing[3].at==Score.place,
  'first and final cadence attacks are the catch and placement cues')
check(Score.logoReveal<Score.logoLock and Score.logoLock==Score.orbitStart
  and Score.orbitEnd<Score.catch and Score.catch<Score.carryStart and Score.place<Score.duration,
  'formation, orbit, catch, carry and placement have distinct ordered intervals')
local behind=Seasons.pose('autumn',Score.orbitStart+(Score.orbitEnd-Score.orbitStart)*.75,720,420,1.4)
local front=Seasons.pose('autumn',Score.orbitStart+(Score.orbitEnd-Score.orbitStart)*.25,720,420,1.4)
check(behind.behind and not front.behind,'ghost changes depth as it orbits the wordmark')
check(not Seasons.pose('autumn',Score.catch-.01,720,420,1.4).holding
  and Seasons.pose('autumn',Score.catch,720,420,1.4).holding,'first heavy attack precisely switches to carrying')
local previousGraphics=love.graphics
local depth=0
love.graphics={}
for _,method in ipairs({'translate','scale','ellipse','polygon','rectangle','circle','line','setLineWidth','rotate'}) do
  love.graphics[method]=function() end
end
love.graphics.push=function() depth=depth+1 end
love.graphics.pop=function() depth=depth-1;assert(depth>=0,'unbalanced seasonal graphics stack') end
love.graphics.setColor=function(r,g,b,a)
  for _,value in ipairs({r,g,b,a}) do assert(value==value and value>=0 and value<=1,'invalid mascot color') end
end
love.graphics.arc=function(mode,closure)
  assert(mode=='fill' or mode=='line','invalid arc drawing mode')
  assert(closure=='open' or closure=='closed' or closure=='pie','arc mode must work on LOVE 11.5')
end
for _,kind in ipairs({'autumn','winter','spring','summer'}) do
  for _,at in ipairs({0,5,8.6,11.8,15.3,Score.duration}) do Seasons.draw(kind,at,720,420,1.4) end
  check(depth==0,'every seasonal drawing path balances graphics state and uses valid drawing modes')
end
love.graphics=previousGraphics
for _,key in ipairs({'launcherAnimations','launcherIntroSeason','launcherLogoCards','launcherCartDesigns'}) do
  local opts={};GenOptions.set(opts,key,'choice',1)
  check(opts[key]=='choice' and not opts.perGeneration,'launcher preferences cannot leak into game-family overrides')
end

local SaveData=require('src.core.SaveData')
local saveOptions,writes=SaveData.saveOptions,0
SaveData.saveOptions=function() writes=writes+1;return true end
local legacy={launcherLayout='classic',launcherClassic=true}
local RI={_ui={}}
RI.new=function() return {launcher=true,sidebarMode=false,_settings=function() return legacy end} end
require('src.import.LauncherLibrary').install(RI)
local ui=RI.new()
check(ui.sidebarMode and ui.section=='games','old Classic preference opens the RetroRecomped library')
check(legacy.launcherLayout=='sidebar' and legacy.launcherClassic==nil and writes==1,
  'migration persists once without changing unrelated options')
RI.new();check(writes==1,'already migrated preferences are not rewritten on every launch')
SaveData.saveOptions=saveOptions

local Importer=require('src.import.RomImporter')
local options=SaveData.defaultOptions()
local settings=setmetatable({ready={},sidebarMode=true,settingsPage='launcher',
  _settings=function() return options end,_dataDirNote=function() return 'Test storage' end,
  _savedropTarget=function() return 'crystal' end},{__index=Importer})
local rows=settings:_settingsRows()
local present={}
for _,entry in ipairs(rows) do
  if entry.row then present[entry.row.id]=entry end
end
check(not present.launcherLayout,'Classic layout is no longer offered in application settings')
check(present.launcherIntroSeason and present.launcherLogoCards,'season and cartridge label controls belong to application settings')
settings:_settingsAction({action='launcherPreviewIntro'})
check(settings._launcherSequence and settings._launcherSequence.kind=='intro','settings preview plays the actual application intro')
settings._launcherSequence=nil;settings.settingsPage=nil;settings._workspaceCategory='game';settings.settingsGen=3
rows=settings:_settingsRows();present={}
for _,entry in ipairs(rows) do if entry.row then present[entry.row.id]=entry end end
check(not present.colors and not present.gbcfx,'Game Boy color controls are absent from GBA preferences')
check(present.settingsGen and present.settingsGen.row.labels[4]=='DS (GEN 4)','game family choices include the supported DS engine')
check(require('src.core.Version').title():match('^RetroRecomped'),'application title uses its own brand')
print('Seasonal launcher and settings: '..n..' checks passed')
