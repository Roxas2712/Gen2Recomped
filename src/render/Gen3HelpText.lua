-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Static Help articles consume the same structured catalog and native font
-- cells as dialogue. Timing/audio operands do not start another printer.
local Font=require('src.render.Font')
local Text=require('src.core.game3.rom_text')
local M={}
local placeholders={[0]='UNKNOWN','PLAYER','VAR1','VAR2','VAR3','KUN','RIVAL',
 'VERSION','AQUA','MAGMA','ARCHIE','MAXIE','KYOGRE','GROUDON'}
local faces={[0]='small',[4]='male',[5]='female'}
local icons={A_BUTTON=0,B_BUTTON=1,L_BUTTON=2,R_BUTTON=3,START_BUTTON=4,SELECT_BUTTON=5,
 DPAD_UP=6,DPAD_DOWN=7,DPAD_LEFT=8,DPAD_RIGHT=9,DPAD_UPDOWN=10,DPAD_LEFTRIGHT=11,DPAD_ANY=12}
local function withFace(name,fn)
 local pushed=name and Font.hasFace(name)
 if pushed then Font.pushFace(name)end
 local ok,result=pcall(fn)
 if pushed then Font.popFace()end
 if not ok then error(result,0)end
 return result
end
function M.layout(nodes,width,keypad,fill)
 assert(type(nodes)=='table'and type(width)=='number'and width>0,'invalid native Help text layout')
 local out,x,y,face,spacing={},0,0,nil,0
 local ink,shadow=1,2
 local function newline()x=0;y=y+15 end
 local function add(code,icon)
  local advance=icon and assert(keypad.regions[icon+1]).width
   or withFace(face,function()return Font.advanceOf(code)end)
  if x>0 and x+advance>width then newline()end
  out[#out+1]={code=code,icon=icon,x=x,y=y,face=face,ink=ink,shadow=shadow}
  x=x+math.max(spacing,advance)
 end
 local function text(value)
  local remaining=tostring(value)
  while true do
   local at=remaining:find('\n',1,true)
   local part=at and remaining:sub(1,at-1)or remaining
   if part:match('^%s+$')then for _,code in ipairs(Font.encode(part))do add(code)end end
   for word in part:gmatch('%s*%S+%s*')do
    local codes=Font.encode(word)
    local length=withFace(face,function()
     local n=0;for _,code in ipairs(codes)do n=n+math.max(spacing,Font.advanceOf(code))end;return n
    end)
    if x>0 and x+length>width then newline()end
    for _,code in ipairs(codes)do add(code)end
   end
   if not at then break end
   newline();remaining=remaining:sub(at+1)
  end
 end
 for _,node in ipairs(nodes)do
  if node.t=='text'then text(node.s)
  elseif node.t=='ph'then text(Text._expand('{'..(placeholders[node.code]or('PH:%02X'):format(node.code))..'}',fill))
  elseif node.t=='tag'then
   if node.control==0xF9 then add(256+node.code)
   elseif node.control==0xF8 then add(nil,node.code)
   else
    local icon=icons[node.tag:match('^%{(.-)%}$')]
    if icon then add(nil,icon)else text(Text._expand(node.tag,fill))end
   end
  elseif node.t=='nl'or node.t=='scroll'or node.t=='para'then newline()
  elseif node.t=='ext'then
   local cmd,a=node.cmd,node.args or{}
   if cmd==1 then ink=a[1]elseif cmd==3 then shadow=a[1]
   elseif cmd==4 then ink,shadow=a[1],a[3]
   elseif cmd==6 then face=faces[a[1]]elseif cmd==7 then face=nil
   elseif cmd==12 then text(node.literal or'')
   elseif cmd==13 or cmd==18 then x=a[1]
   elseif cmd==14 then y=a[1]
   elseif cmd==17 then x=x+a[1]
   elseif cmd==19 then x=math.max(x,a[1])
   elseif cmd==20 then spacing=a[1]end
  elseif node.t~='eos'then error('unknown native Help text node: '..tostring(node.t))end
 end
 return{glyphs=out,height=y+15}
end
function M.draw(layout,x,y,palette,icons,scroll)
 for _,glyph in ipairs(layout.glyphs)do
  local yy=y+glyph.y-(scroll or 0)*15
  if glyph.icon~=nil then
   local icon=assert(icons[glyph.icon+1],'native keypad icon unavailable')
   love.graphics.setColor(1,1,1,1);love.graphics.draw(icon,x+glyph.x,yy)
  else
   withFace(glyph.face,function()
    Font.pushStyle({text=assert(palette[glyph.ink+1]),shadow=assert(palette[glyph.shadow+1])})
    local ok,why=pcall(Font.drawCode,glyph.code,x+glyph.x,yy)
    Font.popStyle();if not ok then error(why,0)end
   end)
  end
 end
end
return M
