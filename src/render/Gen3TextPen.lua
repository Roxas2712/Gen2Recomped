-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared native measurement/paint cursor for embedded GBA positioning codes.
-- Ordinary UTF-8 strings continue through the existing proportional font path.
local Font=require('src.render.Font')
local M={}
local codes={[0x0d]=true,[0x0e]=true,[0x11]=true,[0x12]=true,[0x13]=true,[0x14]=true}
local compound='{POKEBLOCK}'
local firstCompound,lastCompound=0x55,0x59
function M.isCompound(text)return text==compound end
function M.compoundWidth(text)
 if text~=compound then return end
 local width=0;for code=firstCompound,lastCompound do width=width+Font.advanceOf(code)end
 return width
end
function M.drawCompound(text,x,y)
 if text~=compound then return end
 local pen=x
 for code=firstCompound,lastCompound do Font.drawCode(code,pen,y);pen=pen+Font.advanceOf(code)end
 return pen-x
end
function M.has(text)return type(text)=='string'and(text:find(string.char(0xfc),1,true)~=nil or text:find(compound,1,true)~=nil)end
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
 local function glyph(glyph,code)
  if opts.limitChars and count>=opts.limitChars then return false end
  local width=code and Font.advanceOf(code)or Font.width(glyph)
  if paint and(not opts.maxWidth or x+width<=opts.maxWidth)then paint(glyph,x,y,code)end
  trailing=minWidth>0 and 0 or spacing
  x=x+math.max(width,minWidth)+trailing;count=count+1
  return true
 end
 local function ordinary(value)
  for _,span in ipairs(Font.split(value))do
   if opts.limitChars and count>=opts.limitChars then return false end
   local symbol=value:sub(span.from,span.to)
   if symbol=='\n'or symbol=='\v'or symbol=='\f'then
    widest=math.max(widest,lineWidth());x=0;y=y+(opts.linePitch or 15);trailing=0
    count=count+1
   elseif not glyph(symbol)then return false end
  end
  return true
 end
 local function segment(value)
  local start=1
  while start<=#value do
   local first,last=value:find(compound,start,true)
   if not ordinary(value:sub(start,first and first-1 or #value))then return false end
   if not first then break end
   -- These five native cartridge glyphs form one 40px action label. Do not
   -- re-encode its letters through the ordinary proportional Latin charmap.
   for code=firstCompound,lastCompound do if not glyph(nil,code)then return false end end
   start=last+1
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
