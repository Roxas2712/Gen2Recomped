-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald item_menu.c insertion semantics over the host's physical slots.
local M={}
local Native=require('src.inventory.Gen3RsInventory')
local Serial=require('src.core.SaveSerializer')
local function play(owner)require('src.core.Sound').play(owner.game.data,'Press_AB')end
function M.update(owner,input)
 if not owner.emerald or require('src.core.GameVersion').get()~='emerald'then return false end
 local state=owner.emeraldSwap
 if state then
  if input:wasPressed('up')then owner:moveCursor(-1)
  elseif input:wasPressed('down')then owner:moveCursor(1)
  elseif input:wasPressed('a')or input:wasPressed('select')or input:wasPressed('b')then
   local target=owner.index
   if not input:wasPressed('b')then
    Native.moveBefore(owner.game.save,owner.game.data,state.pocket,state.from,target,state.expected)
   end
   owner.emeraldSwap=nil
   if state.from<target then owner.index=math.max(1,target-1)end
   owner:rebuild();play(owner)
  end
  return true
 end
 if not input:wasPressed('select')then return false end
 local pocket=owner.pockets[owner.pocket].key;local row=owner:selected()
 if not(owner.pick or owner.sell or owner.store or owner.itemPc or owner.scriptRows or owner.pcList)
  and not owner.game.save.gen3PyramidBag and pocket~='TM_HM'and pocket~='BERRY'
  and row and row.id and not row.close then
  local rows=Native.rows(owner.game.save,owner.game.data,pocket)
  if rows and rows[owner.index]and rows[owner.index].id==row.id and rows[owner.index].qty==row.qty then
   owner.emeraldSwap={from=owner.index,pocket=pocket,row=row,expected=Serial.encode(rows)};play(owner)
  end
 end
 return true
end
return M
