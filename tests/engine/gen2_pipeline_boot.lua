-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Exercise native Game:load through its real creation event and Pipelines.
-- ROM import, input and drawing initialization are outside this ordering case.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Game=require('src.core.Game')
local Data=require('src.core.Data')
local Save=require('src.core.SaveData')
local Version=require('src.core.GameVersion')
local P=require('src.render.Pipelines')
local Runtime=require('src.mods.Runtime')
local Events=require('src.mods.Events')
local Hooks=require('src.mods.Hooks')
local Loader=require('src.mods.Loader')
local oldVersion=Version.get()
local oldEvents,oldHooks,oldErrors=Runtime.events,Runtime.hooks,Runtime.errors
local restore={}
local function replace(owner,key,value)
 restore[#restore+1]={owner,key,owner[key]};owner[key]=value
end
local function noop()end
for _,key in ipairs{'load','applyMapEditorOverlay','publishGen2TilesetNames',
 'publishGen2Palettes','publishGen2MapMetadata'}do replace(Data,key,noop)end
for _,name in ipairs{'Gen2MapNames','Gen3MapNames','Gen2Environment','Gen2EncounterViews'}do
 replace(require('src.core.'..name),'publish',noop)
end
replace(require('src.core.Music'),'resetSession',noop)
replace(require('src.core.Input'),'init',noop)
replace(require('src.core.TouchControls'),'init',noop)
replace(require('src.core.TouchControls'),'setHotkeyHandler',noop)
replace(require('src.render.Renderer'),'init',noop)
replace(require('src.translation.Service'),'install',noop)
for _,name in ipairs{'src.render.Font','src.ui.Theme','src.core.Strings'}do replace(require(name),'load',noop)end
local stop={}
local savedLevel,session,created,observed
replace(Save,'loadOptions',function()return {pipelines={voxel=savedLevel,blur=1}}end)
replace(Save,'newGame',function()
 return {player={name='RED',map='FIX_TOWN',x=2,y=2},party={},modData={},
  options=Save.loadOptions()}
end)
replace(Data,'render_pipelines',{
 voxel={levels={'OFF','ON','15','35','50','75','FIRST','THIRD'},drawWorld=function()end},
 blur={levels={'OFF','ON'},worldPresent=function()end},
 native_driver={internal=true},
})
replace(Loader,'new',function()
 local events=Events.new();local errors={}
 events:on('save.created',function(payload)
  created=created+1
  T.eq(payload.save,session.save,'creation event carries actual adopted save')
  observed=P.level('voxel')
  -- A public callback changes one preference, then synchronizes the live
  -- ladder. Unrelated restored preferences must survive that operation.
  P.setLevel('blur',0);P.syncOptions(payload.save.options)
 end)
 return {modSave={},mods={},load=function()Runtime.install(events,Hooks.new(),errors)end,
  status=function()return {loaded={},errors=errors}end}
end)
for _,edition in ipairs{'gold','silver','crystal','red','yellow','emerald'}do
 Version.set(edition)
 for _,level in ipairs{0,1,6,7}do
  savedLevel=level;created=0;observed=nil
  session=setmetatable({bootConfig=function()return {}end,
   applyOptions=function(self,opts)
    local expected=Version.isGen2()and level or 0
    T.eq(observed,expected,edition..' creation callback sees expected live ladder')
    T.eq(opts.pipelines.voxel,expected,edition..' sync preserves camera at creation')
    T.eq(opts.pipelines.blur,0,edition..' callback can change its own display option')
    T.eq(P.level('native_driver'),1,edition..' internal native pipeline stays active')
    P.applyOptions(opts)
    T.eq(P.level('voxel'),expected,edition..' later display apply retains callback result')
    error(stop,0)
   end},{__index=Game})
  local ok,err=pcall(Game.load,session)
  T.check(not ok and err==stop,edition..' actual boot reaches post-event options boundary')
  T.eq(created,1,edition..' boot announces adopted skeleton exactly once')
 end
end
for i=#restore,1,-1 do local row=restore[i];row[1][row[2]]=row[3]end
Runtime.install(oldEvents,oldHooks,oldErrors)
P.install(Data);Version.set(oldVersion)
T.finish('Gen2 restored pipeline before creation callbacks')
