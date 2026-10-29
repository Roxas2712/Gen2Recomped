-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- One ordinary-input move operation, shared by the story operators.
local M={}
function M.attack(game,U,press,slot)
    local b=game.stack:top()
    if getmetatable(b)~=require('src.battle.BattleState')then return 'no active battle'end
    local function advanceBattle()
      for _=1,600 do
        if game.stack:top()~=b then return 'subordinate UI or field'end
        if b.phase=='menu'or b.phase=='moveSelect'then return end
        if b.phase=='messages'then press('b',8)else U.wait(4)end
      end
      return 'battle did not return to its menu'
    end
    local stop=advanceBattle();if stop then return stop end
    if b.phase=='menu'then
      if (b.menuIndex-1)%2==1 then press('left',8)end
      if b.menuIndex>2 then press('up',8)end
      assert(b.menuIndex==1,'Ordinary fight selection did not reach slot one')
      press('a',8)
    end
    if game.stack:top()~=b or b.phase~='moveSelect'then return 'move menu is not active'end
    local chooser=b:menuBattler();local moves=chooser.curMoves
    assert(slot>=1 and slot<=4 and moves[slot],'Requested move does not exist')
    if (moves[slot].pp or 0)<=0 then return 'chosen move has no PP'end
    local column,row=(slot-1)%2,math.floor((slot-1)/2)
    if (b.moveIndex-1)%2~=column then press(column==0 and'left'or'right',8)end
    if math.floor((b.moveIndex-1)/2)~=row then press(row==0 and'up'or'down',8)end
    -- A direction into an absent fourth move correctly retains its old slot;
    -- retry across the occupied first column when approaching move three.
    if b.moveIndex~=slot then
      if (b.moveIndex-1)%2==1 then press('left',8)end
      if math.floor((b.moveIndex-1)/2)~=row then press(row==0 and'up'or'down',8)end
      if (b.moveIndex-1)%2~=column then press(column==0 and'left'or'right',8)end
    end
    assert(b.moveIndex==slot,'Ordinary move navigation did not reach requested slot')
    press('a',12)
    return advanceBattle()or'turn returned to battle menu'
end
return M
