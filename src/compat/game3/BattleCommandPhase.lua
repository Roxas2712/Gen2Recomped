-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A borrowed native move-selection boundary, not a command queue. Only the
-- existing controller commits the returned choice and advances battle rules.
local M={}
local pending
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function integer(v,lo,hi)return type(v)=='number'and v==v and v%1==0 and v>=lo and v<=hi end
function M.take()
 local p=pending
 if not p or p.consumed or p.committing then return nil end
 p.consumed=true
 return p.command
end
function M.dispatch(screen,action,body,source)
 if pending then
  if pending.screen==screen and pending.committing then
   local values=pack(body(screen,action));pending.result=values;return unpack(values,1,values.n)
  end
  return false,'native command phase is already pending'
 end
 local Battle=require('src.core.game3.battle')
 local game=screen.game
 if Battle._screen()~=screen or not game or game.stack:top()~=screen then
  return false,'native battle does not own input'
 end
 if screen.phase~='moveSelect'and screen.phase~='targetSelect'
     or screen.kind=='link'or screen.spectating or screen.demo or screen.pokedudeDemo
     or screen.palace or screen.arena then return body(screen,action)end
 local actor=screen:menuBattler();local slot
 for i,m in ipairs(actor and actor.curMoves or{})do if m==action then slot=i;break end end
 -- Forced actions, switches and other sequencers keep their existing owner.
 if not slot then return body(screen,action)end
 local ids=require('src.compat.gen1.BattleIds').new(screen.data)
 local move=ids:read('moves',action.id)
 if not move then return body(screen,action)end
 local pos=screen:choosingSlotNow()
 local target=screen.chosenTargets and screen.chosenTargets[pos]
 local targetId=target and target.position
 local command={kind='move',user='player',battler=pos,slot=slot,move=move,target=targetId}
 local admission=Battle.getState()
 local p={screen=screen,command=command};pending=p
 local phase,turn,save,data,stack,mon,moves=screen.phase,screen.turnCount,game.save,game.data,game.stack,actor.mon,actor.curMoves
 local result=pack(pcall(function()
  local nextCommand=source()
  if Battle._screen()~=screen or Battle.getState()~=admission or game.stack~=stack or stack:top()~=screen
      or game.save~=save or game.data~=data or screen.data~=data or not ids.valid()
      or screen.phase~=phase or screen.turnCount~=turn or screen:menuBattler()~=actor
      or actor.mon~=mon or actor.curMoves~=moves or moves[slot]~=action
      or screen:choosingSlotNow()~=pos or screen.result or screen.dead or screen.waitingUI
      or actor.fainted or not actor.mon or(actor.mon.hp or 0)<=0
      or(screen.chosenTargets and screen.chosenTargets[pos])~=target then
   return false,'native command context changed'
  end
  if nextCommand==nil then
   if screen.chosenTargets then screen.chosenTargets[pos]=nil end
   screen.phase='moveSelect'
   return false,'native move selection cancelled'
  end
  assert(type(nextCommand)=='table'and getmetatable(nextCommand)==nil,'command must be a plain move record')
  local fields={kind=true,user=true,battler=true,slot=true,move=true,target=true}
  for key in pairs(nextCommand)do assert(fields[key],'unsupported native move command field')end
  assert(nextCommand.kind=='move'and nextCommand.user=='player'and nextCommand.battler==pos,'native move command changed its acting battler')
  local selected=nextCommand.slot
  assert(integer(selected,1,#moves)and selected<=4,'invalid native move command slot')
  local nextMove=moves[selected]
  assert(nextCommand.move==ids:read('moves',nextMove.id),'native command move does not match its slot')
  local chosen=nextCommand.target;local nativeTarget
  if chosen~=nil then
   assert(integer(chosen,0,3),'invalid native move target')
   for _,candidate in ipairs(require('src.battle.Targeting').choices(screen,actor))do
    if candidate.position==chosen then nativeTarget=candidate;break end
   end
   assert(nativeTarget,'native move target is not selectable')
  end
  if not Battle._flushNative(screen)then return false,'native command admission retired'end
  p.committing=true
  local selection=package.loaded['src.battle.Gen3MoveSelection']
  if selection and selection.manualReason then
   local reason=selection.manualReason(screen,actor,nextMove,selected)
   if selected==slot and chosen==targetId and not reason then return body(screen,action)end
  end
  -- Modified choices go back through the native refusal/target selector.
  if screen.chosenTargets then screen.chosenTargets[pos]=nil end
  screen.phase='moveSelect'
  local a,b=screen:chooseMove(selected)
  if screen.phase=='targetSelect'and nativeTarget then
   for i,candidate in ipairs(screen.targetChoices or{})do
    if candidate==nativeTarget then
     a,b=screen:chooseTarget(i)
     if p.result then return unpack(p.result,1,p.result.n)end
     return a,b
    end
   end
   return false,'native move target changed'
  end
  if p.result then return unpack(p.result,1,p.result.n)end
  return a,b
 end))
 pending=nil
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
return M
