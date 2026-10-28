-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared native measurement/paint cursor for embedded GBA positioning codes.
-- Ordinary UTF-8 strings continue through the existing proportional font path.
local Font=require('src.render.Font')
local M={}
local codes={[0x0d]=true,[0x0e]=true,[0x11]=true,[0x12]=true,[0x13]=true,[0x14]=true}
function M.has(text)return type(text)=='string'and text:find(string.char(0xfc),1,true)~=nil end
function M.layout(text,opts,paint)
 opts=opts or{}
 -- Validate the entire stream before paint. A missing operand must never be
 -- swallowed as a glyph or leave half of a malformed label on the canvas.
 local at=1
 while true do
  local p=text:find(string.char(0xfc),at,true);if not p then break end
  assert(p+2<=#text,'truncated native text pen control')
  assert(codes[text:byte(p+1)],'unsupported native text pen control')
  at=p+3
 end
 local x,y,widest,minWidth,count=0,0,0,0,0
 local spacing=opts.letterSpacing or 0
 local trailing=0
 local function lineWidth()return math.max(0,x-trailing)end
 local function segment(value)
  for _,span in ipairs(Font.split(value))do
   if opts.limitChars and count>=opts.limitChars then return false end
   local glyph=value:sub(span.from,span.to)
   if glyph=='\n'or glyph=='\v'or glyph=='\f'then
    widest=math.max(widest,lineWidth());x=0;y=y+(opts.linePitch or 15);trailing=0
   else
    local width=Font.width(glyph)
    if paint and(not opts.maxWidth or x+width<=opts.maxWidth)then paint(glyph,x,y)end
    trailing=minWidth>0 and 0 or spacing
    x=x+math.max(width,minWidth)+trailing
   end
   count=count+1
  end
  return true
 end
 at=1
 while at<=#text do
  local p=text:find(string.char(0xfc),at,true)
  if not segment(text:sub(at,p and p-1 or #text))then break end
  if not p then break end
  local cmd,value=text:byte(p+1,p+2)
  if cmd==0x14 then minWidth=value
  elseif cmd==0x0e then y=value
  else
   trailing=0
   if cmd==0x11 then x=x+value
   elseif cmd==0x13 then x=math.max(x,value)
   else x=value end
  end
  at=p+3
 end
 return math.max(widest,lineWidth())
end
return M
