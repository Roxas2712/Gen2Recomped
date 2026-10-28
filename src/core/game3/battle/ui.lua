-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native battle surface and input-phase seams. Sprite/particle presentation
-- capabilities are separate; this module does not advertise that protocol.
local Battle=require('src.core.game3.battle')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Scope=require('src.render.GraphicsScope')
local Ui={}
function Ui.drawMenuFrames(mode)return require('src.ui.game3.battle_chrome').drawMenuFrames(mode)end
function Ui.voiceoverDim()
 local screen=Battle._screen();return screen and require('src.battle.Gen3VoiceoverPresentation').dim(screen)or 0
end
function Ui.litHealthboxShown()
 local screen=Battle._screen();return screen and require('src.battle.Gen3VoiceoverPresentation').lit(screen)or false
end
function Ui.moveTypeOf(mon,slot,def)
 local types=mon and mon.moveTypes
 if types and types[slot]~=nil then return types[slot]end
 return def and def.type
end
function Ui.ppColorState(current,maximum)
 current,maximum=tonumber(current)or 0,tonumber(maximum)or 0
 if current~=current or maximum~=maximum or current==math.huge or maximum==math.huge
  or current==-math.huge or maximum==-math.huge then return nil,'invalid PP observation'end
 local palette=require('src.ui.Gen3SummaryLayout').ppColor(current,maximum)
 return palette==12 and 3 or palette-9
end
function Ui.quickBallPrompt()
 local screen=Battle._screen();return screen and require('src.battle.QuickItem').prompt(screen)or nil
end
function Ui.ballQuad(ball,frame)
 return require('src.core.game3.battle.ui_ball_art').quad(ball,frame)
end
local function selectionBattler(key)
 if type(key)=='number' and (key~=key or key%1~=0 or key<0 or key>3) then return end
 local screen=Battle._screen();if not screen then return end
 local id=require('src.core.game3.battle.anim_coords').idOf(key)
 if id==nil or id>=2 and not screen:isDouble() then return end
 return screen,screen:battlerAt(id)
end
function Ui.targetHidden(key)
 local screen,b=selectionBattler(key)
 return screen and require('src.battle.Gen3SelectionPresentation').hidden(screen,b) or false
end
function Ui.bounceOffset(kind,key)
 if kind~='hb' and kind~='mon' then return 0 end
 local screen,b=selectionBattler(key)
 return screen and require('src.battle.Gen3SelectionPresentation').offset(screen,kind,b) or 0
end
function Ui.previewCoeff(key)
 local screen,b=selectionBattler(key)
 local fx=screen and screen:gen3AnimSpecialMonState(b)
 return math.max(0,math.min(16,(fx and fx.white or 0)*16))
end
-- Keep PP thresholds shared with the existing native summary renderer.
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
function Ui.statusHUDVisible()
  local screen=Battle._screen();return screen and screen:statusHUDVisible()or false
end
function Ui.bottomUIVisible(state)
  local screen=Battle._screen(state);return screen and screen:bottomUIVisible()or false
end
function Ui.moveGridNavigation()
  local screen=Battle._screen();return screen and screen:moveGridNavigation()or false
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
  if key=='_swap'then
    local index=screen.moveSwapIndex
    return index and{cursor=index-1}or nil
  end
  if key=='_swapIndex'then return screen.moveSwapIndex end
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
 elseif key=='_st'or key=='_mode'or key=='_active'or key=='_swap'or key=='_swapIndex'then
  error('native battle UI observation is read-only: '..key,2)
 else rawset(t,key,value)end
end})
return Ui
