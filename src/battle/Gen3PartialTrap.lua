-- GBA binding is target-owned residual damage, never a forced move lock.
-- pret/pokeruby: SetMoveEffect(MOVE_EFFECT_WRAP), ENDTURN_WRAP and switch cleanup.
local M={}
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local cache=setmetatable({},{__mode='k'})
local function name(b)return b.isPlayer and b.name or('Enemy '..b.name)end
local function position(b)return b.position~=nil and b.position or(b.isPlayer and 0 or 1)end
function M.clear(b)
  b.gbaWrapTurns,b.gbaWrapMove,b.gbaWrapSource=nil,nil,nil
end
function M.active(b)
  return V.isGen3()and b and b.mon and b.mon.hp>0 and(tonumber(b.gbaWrapTurns)or 0)>0
end
function M.apply(ctx,damage)
  if not V.isGen3()then return end
  local target=ctx.target
  if (damage or ctx.totalDealt or 0)<=0 or target.mon.hp<=0 or target.substituteHP or ctx.brokeSub
    or M.active(target)then return end
  -- Stored as 3..6: ENDTURN_WRAP decrements before damage, including the
  -- initial hit's turn, then releases without damage when it reaches zero.
  target.gbaWrapTurns=ctx.rng(0,3)%4+3
  target.gbaWrapMove=ctx.move.id
  target.gbaWrapSource=position(ctx.user)
  ctx.say(Strings('%s was trapped\nby %s!',ctx.displayName(target),ctx.move.name or ctx.move.id))
end
function M.builtin(id,base)
  if not V.isGen3()or not base or(id~='TRAPPING_EFFECT'and id~='RAPID_SPIN_EFFECT')then return base end
  local byId=cache[base]
  if not byId then byId={};cache[base]=byId end
  if byId[id]then return byId[id]end
  local out={};for k,v in pairs(base)do out[k]=v end
  if id=='TRAPPING_EFFECT'then
    out.beforeAccuracy=nil
    out.afterDamage=M.apply
  else
    out.afterDamage=function(ctx,...)
      if V.isGen3()then
        if (ctx.totalDealt or 0)<=0 or ctx.gbaNoEffect then return end
        if M.active(ctx.user)then
          M.clear(ctx.user)
          ctx.say(Strings('%s spun free!',ctx.displayName(ctx.user)))
        end
      end
      if base.afterDamage then return base.afterDamage(ctx,...)end
    end
  end
  byId[id]=out;return out
end
function M.residual(battle,b)
  if not M.active(b)then return end
  b.gbaWrapTurns=b.gbaWrapTurns-1
  local move=b.gbaWrapMove
  local def=battle.data and battle.data.moves and battle.data.moves[move]
  local label=def and def.name or tostring(move or'BIND')
  if b.gbaWrapTurns<=0 then
    M.clear(b)
    battle:sayNext(Strings('%s was freed\nfrom %s!',name(b),label))
    return
  end
  -- Residual loss ignores Substitute, Endure, Focus Band and direct-hit
  -- bookkeeping, just as poison does. The existing scheduler owns fainting.
  b.mon.hp=math.max(0,b.mon.hp-math.max(1,math.floor(b.mon.stats.hp/16)))
  battle:sayNext(Strings('%s is hurt\nby %s!',name(b),label))
  battle:drainNext()
end
function M.switchOut(battle,previous)
  if not V.isGen3()or not previous then return end
  local pos=position(previous)
  for _,b in battle:activeBattlers()do
    if b~=previous and b.gbaWrapSource==pos then M.clear(b)end
  end
  M.clear(previous)
end
function M.refuseSwitch(battle,b)
  if not M.active(b)then return false end
  battle:say(Strings('%s can\'t be\nswitched out!',name(b)))
  return true
end
function M.alwaysRuns(battle,b)
  return V.isGen3()and require('src.battle.Gen3AIOrder').hold(b,battle)==37
end
function M.signature(b,role)
  local turns=tonumber(b.gbaWrapTurns)or 0
  if turns<=0 then return ':wrap=0'end
  local source=b.gbaWrapSource
  if role=='guest'and type(source)=='number'then source=source%2==0 and source+1 or source-1 end
  return ':wrap='..turns..','..tostring(b.gbaWrapMove)..','..tostring(source)
end
return M
