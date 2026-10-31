-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FRLG map_name_popup.c: BG0 window (1,29), standard tiles/palette 3.
local M={}
function M.geometry(sign)
 local inner=sign.width or 14
 local elapsed=144-sign.frames
 local visible=math.max(0,math.min(24,elapsed*2,sign.frames*2))
 return {x=0,y=visible-32,width=(inner+2)*8,height=32,
  textX=8,textY=visible-22,textWidth=inner*8}
end
function M.draw(sign)
 local Font=require('src.render.Font');local g=love.graphics
 local rect=M.geometry(sign)
 local face=Font.pushFace('normal')
 local ok,why=pcall(function()
  -- MapNamePopupCreateWindow uses gStdTextWindow_Gfx, independent of the
  -- save's FRAME option. Menu frames also have a different palette.
  Font.drawStandardBox(0,rect.y/8,rect.width/8,4)
  local two=Font.beginTwoTone({98/255,98/255,98/255,1},
   {214/255,214/255,206/255,1})
  local drawn,err=pcall(Font.draw,sign.name,
   rect.textX+math.max(0,math.floor((rect.textWidth-Font.width(sign.name))/2)),rect.textY)
  if two then Font.endTwoTone()end
  if not drawn then error(err,0)end
 end)
 if face then Font.popFace()end
 g.setColor(1,1,1,1)
 if not ok then error(why,0)end
end
return M
