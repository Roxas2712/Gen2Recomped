-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Decorations borrow the actual native panel/window/frame owners.
local Native=require('src.battle.Gen3Battle')
local Font=require('src.render.Font')
local Version=require('src.core.GameVersion')
local M={}
local function rs(b)
 local v=Version.get();local owner=b.rsBattlePanel
 if (v=='ruby'or v=='sapphire')and owner and owner.chrome and owner.images
  and not b.safari and Native.width(b)==240 then return owner end
end
function M.rects(b,which)
 local s,w=Native.strip(b),Native.windows(b)
 if which=='action'then
  if b.safari then return{{s.tx,s.ty,s.tw,s.th}}end
  return{{w.prompt.tx,w.prompt.ty,w.prompt.tw,w.prompt.th},{w.action.tx,w.action.ty,w.action.tw,w.action.th}}
 elseif which=='moves'then
  local right=20
  if w.moves then right=math.max(w.moves[2].tx+w.moves[2].tw,w.moves[4].tx+w.moves[4].tw)-s.tx end
  local detail=s.tx+20
  if w.moves then detail=math.max(w.moves[2].tx+w.moves[2].tw,w.moves[4].tx+w.moves[4].tw)end
  local edge=Native.extra(b)/8;detail=detail+edge
  return{{s.tx,s.ty,right,s.th},{detail,s.ty,30+edge-detail,s.th}}
 end
 return{}
end
function M.panel(b,which)
 local owner=rs(b)
 if owner and owner.images[which]then
  love.graphics.setColor(1,1,1,1);love.graphics.draw(owner.images[which],0,112)
  return true,false -- Native RS user frames are a separate native layer.
 end
 local drawn=Native.drawPanel(b,which)
 return drawn,drawn==true -- Generic native panels already contain the frame.
end
function M.rsFrames(b,which,owner)
 owner=owner or rs(b);if not owner then return false end
 owner.chrome.setFrameType(math.max(0,((b.game.save.options or{}).gen3Frame or 1)-1))
 local rectangles=which=='action'and{{18,15,11,4}}
  or which=='moves'and{{1,15,20,4},{23,15,6,4}}or{}
 for _,r in ipairs(rectangles)do owner.chrome.userFrame(owner.chrome._frameType or 0,r[1],r[2],r[3],r[4])end
 return true,#rectangles
end
function M.draw(b,which,included)
 if included then return true,0 end
 local owner=rs(b);if owner then return M.rsFrames(b,which,owner)end
 local rectangles=M.rects(b,which)
 for _,r in ipairs(rectangles)do Font.drawBox(r[1],r[2],r[3],r[4])end
 return true,#rectangles
end
return M
