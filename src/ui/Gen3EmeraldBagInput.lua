-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald repeats vertical list input (40 initial frames, then every five).
-- Pocket switches and actions remain fresh presses, as in item_menu.c.
local M={}
function M.update(owner,input)
 local view,keys
 if input.isDown then
  owner.emeraldView=owner.emeraldView or require('src.ui.Gen3EmeraldBagView').new(owner)
  view=owner.emeraldView
  if not view.keys then
   local List=view.load('src.ui.game3.list_menu')
   view.keys=setmetatable({keyRepeat=true,repeatDelay=List.REPEAT_START,
    repeatRate=List.REPEAT_CONTINUE},List)
  end
  keys=view.keys;keys:trackHeld(input)
 end
 if not owner.emeraldSwap and not owner.lockPocket then
  if input:wasPressed('left')then owner:movePocket(-1);return end
  if input:wasPressed('right')then owner:movePocket(1);return end
 end
 -- Share the same repeat clock with insertion mode without synthesizing an
 -- action or changing the input object used by another screen.
 local repeated=input
 if keys then
  view.repeatInput=view.repeatInput or {wasPressed=function(self,key)
   if key=='up'or key=='down'then return self.keys:repeated(self.input,key)end
   return self.input:wasPressed(key)
  end}
  repeated=view.repeatInput;repeated.keys,repeated.input=keys,input
 end
 if require('src.ui.Gen3EmeraldBagReorder').update(owner,repeated)then return end
 if input:wasPressed('a')then owner:choose()
 elseif input:wasPressed('b')then owner:close()
 elseif repeated:wasPressed('up')then owner:moveCursor(-1)
 elseif repeated:wasPressed('down')then owner:moveCursor(1)end
end
return M
