-- Native hotbar actions, persistent world, pointer ownership and editor.
-- Memory-only persistence; no ROM, player profile, OS touch or GPU claim.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local files={}
local fs=T.sdk.memfs(files)
fs.remove=function(path) files[path]=nil;return true end
fs.createDirectory=function()return true end
fs.getSaveDirectory=function()return '/memory-only-hotbar' end
love.filesystem=fs
love.system=love.system or {}
love.system.getOS=function()return 'Linux'end
local image=love.graphics.newImage
love.graphics.newImage=function(...)
  local result=image(...)
  function result:setFilter(min,mag) self.filter={min,mag} end
  return result
end
local W,H,OX,OY,SW,SH=640,480,0,0,640,480
love.graphics.getDimensions=function()return W,H end
love.graphics.getPixelDimensions=function()return W*2,H*2 end
love.window=love.window or {}
love.window.getSafeArea=function()return OX,OY,SW,SH end
local Version=require('src.core.GameVersion')
local Save=require('src.core.SaveData')
Save.persistenceFs=function()return fs end
Save.resetSlotState()
Version.set('crystal')
local Touch=require('src.core.TouchControls')
local Input=require('src.core.Input')
local Game=require('src.core.Game')
local Stack=require('src.core.StateStack')
local Runtime=require('src.mods.Runtime')
local Hooks=require('src.mods.Hooks')
local hooks=Hooks.new()
Runtime.install(require('src.mods.Events').new(),hooks,{})
local stack=setmetatable({},{__index=Stack});stack:init()
local g=setmetatable({save=Save.newGame({version='crystal'}),data=T.fixtures.fresh(),stack=stack}, {__index=Game})
local captures=0
local world={isOverworld=true,captureSave=function(_,save)
  captures=captures+1;save.money=4321
end}
-- This offered viewport base retains its real world-on-stack owner.
g.overworld=world;stack:push(world)
Input:init();Touch:init();Touch.active=true;Touch:ensureImages()
Touch:applyOptions({touchControls={enabled=true}})
love.keypressed=function(key)g:keypressed(key)end
love.keyreleased=function(key)Input:keyreleased(key)end
local pointers=0
local unhook=hooks:wrap('input.pointer',function()
  pointers=pointers+1;return true
end,0,'hotbar-owner-fixture')
local function tap(label,id)
  Touch.hotbarOpen=true
  for _,cell in ipairs(Touch:hotbarStrip())do
    if cell.label==label then
      local x,y=cell.x+cell.w/2,cell.y+cell.h/2
      g:touchpressed(id or label,x,y)
      g:touchreleased(id or label,x,y)
      return
    end
  end
  error('missing native cell '..label)
end
T.eq(stack:top(),world,'offered native stack actually owns live world')
tap('SAVE')
T.eq(captures,1,'hotbar F1 reaches actual Game.writeSave and live capture')
local saved=Save.load('crystal')
T.check(saved~=nil,'hotbar writes a decodable native save through memory filesystem')
T.eq(saved and saved.money,4321,'actual saved snapshot contains captured world state')
local loaded
-- World admission is separate from IO; verify actual F2/SaveData.load here.
g.continueGame=function(_,snapshot)loaded=snapshot end
tap('LOAD')
T.eq(loaded and loaded.money,4321,'hotbar F2 reads actual persisted snapshot')
T.eq(pointers,0,'visible native cells have priority over claiming mod pointer hook')

local speed=g.save.options.speed
tap('SPEED')
T.neq(g.save.options.speed,speed,'hotbar SPEED reaches the native speed ladder')
T.eq(Save.optionsFor('crystal').speed,g.save.options.speed,'speed persists through native options IO')
for _,block in ipairs{'transitioning','engaging','emote','scriptMoves','runner'}do
  speed=g.save.options.speed
  world[block]=block=='scriptMoves' and {'move'} or block=='runner' and {isRunning=function()return true end} or true
  tap('SPEED')
  T.eq(g.save.options.speed,speed,'persistent Gen2 world blocks speed while '..block)
  world[block]=nil
end
stack:push({isFixedSpeed=true})
speed=g.save.options.speed;tap('SPEED')
T.eq(g.save.options.speed,speed,'native fixed-speed overlay blocks hotbar speed')
stack:pop();g.linkSession={}
tap('SPEED');T.eq(g.save.options.speed,speed,'native link session blocks speed')
g.linkSession=nil
local Palette=require('src.render.PaletteFX')
local Tilt=require('src.render.Tilt')
local Zoom=require('src.render.Zoom')
Tilt.reset();Zoom.reset()
tap('COLOR')
T.eq(g.save.options.colors,Palette.mode,'COLOR writes actual native palette mode')
tap('TILT');T.eq(Tilt.level,1,'TILT changes actual native renderer state')
tap('ZOOM');T.eq(Zoom.offset,1,'ZOOM changes actual native zoom state')
local round=Save.optionsFor('crystal')
T.eq(round.tilt,1,'tilt persists through actual options IO')
T.eq(round.zoom,1,'zoom persists through actual options IO')
T.eq(pointers,0,'all six actions retain first refusal over mod pointer consumer')

-- A synchronous option reapply clears Touch.touches during key dispatch.
-- The host must retain the complete gesture through a newly opened screen.
local moved,released=0,0
local screen={touchmoved=function()moved=moved+1;return true end,
  touchreleased=function()released=released+1;return true end}
g.writeOptions=function(self)
  Game.writeOptions(self)
  Touch:applyOptions(self.save.options)
  self.stack:push(screen)
end
Touch.hotbarOpen=true
local cell=Touch:hotbarStrip()[3]
local x,y=cell.x+cell.w/2,cell.y+cell.h/2
g:touchpressed('reset-during-press',x,y)
T.eq(Touch.touches['reset-during-press'],nil,'fixture: real option apply resets live pad contacts')
g:touchmoved('reset-during-press',320,240)
g:touchreleased('reset-during-press',320,240)
T.eq(moved,0,'new screen cannot inherit movement from hotbar-owned gesture')
T.eq(released,0,'new screen cannot inherit release from hotbar-owned gesture')
T.eq(pointers,0,'mod cannot inherit remainder of reset pad gesture')
T.eq(g._padPointerIds['reset-during-press'],nil,'release retires host gesture owner')
g.writeOptions=nil;stack:pop()
g._padPointerIds={gone=true,kept=true,mouse=true}
love.touch={getTouches=function()return {'kept'}end}
g:_pollPadPointers()
T.eq(g._padPointerIds.gone,nil,'cancelled native contacts do not leak host owners')
T.check(g._padPointerIds.kept,'poll retains an actual held finger')
T.check(g._padPointerIds.mouse,'OS touch list cannot cancel the mouse owner')
g:touchpressed('gone',320,240)
T.eq(pointers,1,'cancelled id can be used by a new ordinary mod gesture')
g._padPointerIds.reused=true
g:touchpressed('reused',320,240)
T.eq(g._padPointerIds.reused,nil,'new press clears an obsolete id owner')
T.eq(pointers,2,'reused id outside pad reaches actual mod hook')
unhook()

-- Safe-area geometry, rotations and edited bottom toggle at native scale limits.
for _,size in ipairs{{380,720},{800,400}}do
  W,H=size[1],size[2];OX,OY,SW,SH=12,20,W-24,H-32
  for _,scale in ipairs{.6,1,1.6}do
    Touch:init();Touch.active=true;Touch:ensureImages()
    Touch:applyOptions({touchControls={enabled=true}});Touch:setScale(scale)
    local L=Touch:layout()
    for _,name in ipairs{'l','r'}do
      T.eq(Touch:hitTest(L[name].cx,L[name].cy),name,'native shoulder remains reachable '..name)
    end
    for _,bottom in ipairs{false,true}do
      if bottom then Touch:setControlCenter('hotbar',OX+SW/2,OY+SH-2) end
      L=Touch:layout();Touch.hotbarOpen=true
      for _,entry in ipairs(Touch:hotbarStrip())do
        T.check(entry.x>=OX and entry.x+entry.w<=OX+SW,'cell stays in safe horizontal area')
        T.check(entry.y>=OY and entry.y+entry.h<=OY+SH,'cell stays in safe vertical area')
        T.check(not (L.hotbar.cx>=entry.x and L.hotbar.cx<=entry.x+entry.w
          and L.hotbar.cy>=entry.y and L.hotbar.cy<=entry.y+entry.h),
          'strip cannot cover its own closing toggle')
      end
    end
  end
end

-- Normal Options input persists OFF/ON, preserving orientation preferences.
W,H,OX,OY,SW,SH=640,480,0,0,640,480
love.system.getOS=function()return 'Android'end
g.input={pressed={}}
g.input.wasPressed=function(self,key)return self.pressed[key]end
local menu=require('src.ui.OptionsMenu').new(g);stack:push(menu)
local page
for index,row in ipairs(menu.rows)do
  if row.id=='hotbar' then menu.index=index;page=menu;break end
end
T.check(page~=nil,'mobile Options exposes real hotbar row')
if page then
  g.input.pressed={right=true};page:update(1/60);g.input.pressed={}
  T.eq(g.save.options.hotbar,false,'normal Options input turns hotbar off')
  T.eq(Save.optionsFor('crystal').hotbar,false,'hotbar OFF is persisted')
  T.eq(Touch:hotbarShown(),false,'OFF reaches real pad')
  g.input.pressed={right=true};page:update(1/60);g.input.pressed={}
  T.eq(Touch:hotbarShown(),true,'normal Options input restores hotbar')
end
stack:pop()
local Editor=require('src.ui.TouchControlsEditor')
for _,size in ipairs{{380,720},{800,400}}do
  W,H=size[1],size[2];SW,SH=W,H
  Editor.load();Editor.draw()
  local z=Touch:layout().hotbar
  T.eq(Touch:hotbarCellAt(z.cx,z.cy),nil,'layout preview has no invisible live cells')
  Editor.touchpressed('edit',z.cx,z.cy)
  T.eq(Editor.drag and Editor.drag.name,'hotbar','default toggle stays draggable past editor chrome')
  Editor.touchmoved('edit',W*.4,H*.5);Editor.touchreleased('edit')
  local movedToggle=Touch:layout().hotbar
  T.check(math.abs(movedToggle.cx-W*.4)<1,'actual editor drag moves hotbar center')
  Editor.unload()
end
Touch:init();Tilt.reset();Zoom.reset()
Runtime.install(nil,nil,nil)
T.finish('native hotbar actions, ownership, safe area and editor')
