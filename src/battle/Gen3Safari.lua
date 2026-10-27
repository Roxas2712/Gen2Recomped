-- Host queue/input bridge for the native GBA Safari rules.
local M={}
local Rules=require('src.battle.Gen3SafariRules')
local function spec(b)return assert(b.data.constants.gen3SafariNative,'Missing native Safari data')end
local IR
function M.text(b,key,buff)
  local s=spec(b)
  IR=IR or require('compat.gen1-rs.Loader').new('emerald')('src.core.game3.scripting.text_ir')
  local values={B_PLAYER_NAME=b.game.save.player.name,B_OPPONENT_MON1_NAME=b.enemy.name,
    B_BUFF1=buff or b.enemy.name,B_LAST_ITEM=b.data.items.SAFARI_BALL and b.data.items.SAFARI_BALL.name or'SAFARI BALL'}
  local codes={};for code,name in pairs(IR.dialect(s.dialect).B_TXT)do codes[code]=values[name]end
  return IR.toAscii(assert(s.textIR[key],'Missing native Safari text '..key),{dialect=s.dialect,battle=codes})
    :gsub('\\l','\v'):gsub('\\p','\f'):gsub('{POKEBLOCK}','POKéBLOCK')
end
function M.init(b)
  local s=spec(b);local v=require('src.core.GameVersion').get()
  assert(require('src.import.Gen3SafariAssets').valid(s,v),'Incomplete native Safari data')
  b.gen3Safari=Rules.new(v,b.enemy.def.catchRate,b.enemy.def.safariFleeRate,b.safari.balls,s)
  b.safariCatchRate=Rules.catchRate(b.gen3Safari)
end
function M.actions(b)return Rules.actions(b.gen3Safari.edition)end
function M.allowed(b,action)
  for _,v in ipairs(M.actions(b))do if v==action then return true end end;return false
end
local function raw(b)return function()return b.rng(0,65535)end end
function M.full(b)
  if #(b.game.save.party or{})<6 then return false end
  local Boxes=require('src.pokemon.Boxes');local boxes=b.game.save.boxes or{}
  for i=1,Boxes.count()do if not boxes[i]or Boxes.firstFree(boxes[i])then return false end end
  return true
end
local function turn(b,choice,block)
  -- Opponent selection precedes action execution in battle_controller_opponent.
  local fled=Rules.flees(b.gen3Safari,raw(b))
  b.phase=require('src.battle.BattleQueuePhase').name();b.afterQueue='menu'
  if choice=='ball'then
    b:safariBallAction(function()M.enemyTurn(b,fled)end);return
  elseif choice=='go_near'then
    local id=Rules.goNear(b.gen3Safari,spec(b))
    b:say(M.text(b,id=='STRINGID_CREPTCLOSER'and'goNear'or'tooNear'))
  elseif choice=='pokeblock'then
    local mon=b.enemy.mon;local nature=(mon.personality or 0)%25
    -- Existing saves may only carry the stable nature ID.
    if not mon.personality then for i,id in ipairs(b.data.constants.natureOrder or{})do if mon.nature==id then nature=i-1;break end end end
    local result=Rules.throwPokeblock(b.gen3Safari,spec(b),nature,block)
    b:say(M.text(b,'pokeblock'));b:say(M.text(b,({'curious','enthralled','ignored'})[result+1],require('src.inventory.Pokeblocks').name(b.data,block)))
  elseif choice=='bait'then
    Rules.throwBait(b.gen3Safari,raw(b));b:say(M.text(b,'bait'))
  elseif choice=='rock'then
    Rules.throwRock(b.gen3Safari,raw(b));b:say(M.text(b,'rock'))
  end
  b.safariCatchRate=Rules.catchRate(b.gen3Safari)
  b:act(function()M.enemyTurn(b,fled)end)
end
function M.action(b,choice)
  if not M.allowed(b,choice)then return false end
  if choice=='run'then
    b.phase=require('src.battle.BattleQueuePhase').name();b.afterQueue='finish';b.result='run'
    require('src.core.Sound').play(b.data,'Run');b:say(M.text(b,'gotAway'));return true
  end
  if choice=='ball'and M.full(b)then
    b.phase=require('src.battle.BattleQueuePhase').name();b.afterQueue='menu'
    b:say(M.text(b,'boxFull'));return true
  end
  if choice=='pokeblock'then
    -- The case owns selection; only a confirmed, still-owned slot is removed.
    -- Cancelling spends neither a turn nor a random draw.
    b.waitingUI=true
    local done=false
    b.game.stack:push(require('src.ui.Gen3PokeblockCase').new(b.game,{pickOnly=true,
      onCancel=function()if done then return end;done=true;b.waitingUI=nil end,
      onPick=function(slot,block)
        if done then return end;done=true;b.waitingUI=nil
        local P=require('src.inventory.Pokeblocks')
        if P.case(b.game.save)[slot]~=block then return end
        P.remove(b.game.save,slot);turn(b,choice,block)
      end}))
    return true
  end
  turn(b,choice);return true
end
function M.enemyTurn(b,fled)
  if b.safari.balls<=0 then
    b:sayNext(M.text(b,'outOfBalls'));b.result='run';b.afterQueue='finish';return
  end
  if fled then b:safariFled(M.text(b,'wildFled'));return end
  local reaction=Rules.watchStep(b.gen3Safari)
  b.safariCatchRate=Rules.catchRate(b.gen3Safari)
  b:sayNext(M.text(b,reaction))
end
return M
