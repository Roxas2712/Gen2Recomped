-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native battle surface and input-phase seams. Sprite/particle presentation
-- capabilities are separate; this module does not advertise that protocol.
local Battle=require('src.core.game3.battle')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Scope=require('src.render.GraphicsScope')
local Ui={}
-- Keep PP thresholds shared with the published native summary renderer.
function Ui.ppColorIndex(current,maximum)
 return require('src.ui.Gen3SummaryLayout').ppColor(current,maximum)
end
local function call(name,...)
  local facade=require('src.core.Game3');local who=facade._callbackOwner()
  local seams=package.loaded['src.mods.ModSeams']
  for i=#(seams and seams._journal or{}),1,-1 do
    local change=seams._journal[i]
    if change.tbl==Ui and change.key==name and change.after==Ui[name]then who=change.owner;break end
  end
  return facade._withCallbackOwner(who,Ui[name],...)
end
local function query(method,state)
  local screen=Battle._screen(state);if not screen then return false end
  if type(screen[method])~='function'then return nil,'native UI query unavailable: '..method end
  return screen[method](screen)
end
function Ui.statusHUDVisible()return query('statusHUDVisible')end
function Ui.bottomUIVisible(state)
  return query('bottomUIVisible',state)
end
function Ui.moveGridNavigation()
  return query('moveGridNavigation')
end
function Ui.dialogPending()
 local screen=Battle._screen();if not screen then return false end
 if screen.current and screen.current.text~=nil then return true end
 for _,row in ipairs(screen.queue or{})do if row.text~=nil then return true end end
 return false
end
function Ui.busy()
 local screen=Battle._screen();if not screen then return false end
 return screen.game.stack:top()~=screen or screen.waitingUI==true
  or screen.current~=nil or #(screen.queue or{})>0
  or(screen.waitFrames or 0)>0 or(screen.hitSfxWait or 0)>0
end
function Ui.waitingForCommand()
 local screen=Battle._screen()
 return screen~=nil and not screen.result and not Ui.busy()
  and not screen.gen3AnimPlaying and not screen.gen3BallPlaying
  and(screen.phase=='menu'or screen.phase=='moveSelect'or screen.phase=='targetSelect')or false
end
function Ui.bindState(state)
  if state==nil then
    if Battle.isActive()then return false,'cannot unbind an admitted native battle UI'end
    return true
  end
  if not Battle._screen(state)then return false,'UI state is not the admitted native battle'end
  return true
end
local function pump()return Boundary.invoke('battle.ui.update')end
Ui.pump=pump
local commandPhase=require('src.compat.game3.BattleCommandPhase')
local takeCommand=commandPhase.take
Ui.takeCommand=takeCommand
function Ui._nativeCommand(screen,action,body)
 if Ui.takeCommand==takeCommand then return body(screen,action)end
 return commandPhase.dispatch(screen,action,body,function()return call('takeCommand')end)
end
local function draw(w,h)
  local screen=Battle._screen();if not screen then return false,'no admitted native battle'end
  local bw,bh=screen:uiSize()
  if w~=nil and w~=bw or h~=nil and h~=bh then return false,'UI capture must use the native battle surface'end
  if Boundary.active('battle.ui.draw')then return Boundary.invoke('battle.ui.draw')end
  return Battle._captureNative(screen)
end
Ui.draw=draw
function Ui._nativeDraw(screen,body)
  if Ui.draw==draw then return body(screen)end
  if Boundary.active('battle.ui.draw')then return Boundary.invoke('battle.ui.draw')end
  local w,h=screen:uiSize()
  local ok,result=Scope.call(function()
    return Boundary.dispatch('battle.ui.draw',function()return body(screen)end,function()return call('draw',w,h)end)
  end)
  if not ok then error(result,0)end
  return result
end
function Ui._nativeUpdate(screen,dt,body)
  if Ui.pump==pump then return body(screen,dt)end
  if Boundary.active('battle.ui.update')then return Boundary.invoke('battle.ui.update')end
  return Boundary.dispatch('battle.ui.update',function()return body(screen,dt)end,function()return call('pump',dt)end)
end
setmetatable(Ui,{__index=function(_,key)
  local screen=Battle._screen()
  if key=='_st'then return Battle.getState()end
  if not screen then return nil end
  if key=='_menuIndex'then return screen.menuIndex end
  if key=='_moveIndex'then return screen.moveIndex end
  if key=='_active'then return screen:choosingSlotNow()end
  if key=='_swap'then return screen.moveSwapIndex end
  if key=='_mode'then return({menu='menu',moveSelect='moves',mimicSelect='moves',targetSelect='target'})[screen.phase]or'none'end
end,__newindex=function(t,key,value)
 if key=='_menuIndex'or key=='_moveIndex'then
  local screen=Battle._screen()
  assert(screen and screen.game.stack:top()==screen,'native battle does not own the cursor')
  local limit,phase
  if key=='_menuIndex'then limit,phase=#screen:menuActions(),'menu'
  else local actor=screen:menuBattler();limit,phase=#(actor and actor.curMoves or{}),'moveSelect'end
  assert(screen.phase==phase,'native battle cursor is not active')
  assert(type(value)=='number'and value==value and value%1==0 and value>=1 and value<=math.min(4,limit),'invalid native battle cursor')
  if key=='_menuIndex'then screen.menuIndex=value else screen.moveIndex=value end
 elseif key=='_st'or key=='_mode'or key=='_active'or key=='_swap'then
  error('native battle UI observation is read-only: '..key,2)
 else rawset(t,key,value)end
end})
return Ui
