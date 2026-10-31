-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.world.Gen3FrlgMapPopup')
local Font=require('src.render.Font')
local saved={};for _,k in ipairs{'drawBox','drawStandardBox','pushFace','popFace','beginTwoTone','endTwoTone','draw','width'}do saved[k]=Font[k]end
local calls,face,tones={ },0,0
Font.drawBox=function()error('popup used a selectable menu frame')end
Font.drawStandardBox=function(...)calls.box={...}end
Font.pushFace=function(name)T.eq(name,'normal');face=face+1;return true end
Font.popFace=function()face=face-1 end
Font.beginTwoTone=function()tones=tones+1;return true end
Font.endTwoTone=function()tones=tones-1 end
Font.width=function(text)return #text*6 end
Font.draw=function(...)calls.text={...}end
for _,width in ipairs{14,19,22}do
 for _,frames in ipairs{144,143,138,132,90,12,6,1,0}do
  local sign={width=width,frames=frames,name='PALLET TOWN'}
  local before=require('src.mods.Merge').deepCopy(sign)
  M.draw(sign)
  local shown=math.max(0,math.min(24,(144-frames)*2,frames*2))
  T.same(calls.box,{0,(shown-32)/8,width+2,4},'standard BG0 border uses source window dimensions')
  T.same(calls.text,{'PALLET TOWN',8+math.floor((width*8-66)/2),shown-22},'normal font is centered inside the native window')
  T.same(sign,before,'draw cannot change popup lifetime or name')
  T.eq(face,0);T.eq(tones,0)
 end
end
Font.draw=function()error('deliberate text renderer failure')end
T.raises(function()M.draw({frames=90,name='ROUTE 1'})end,'deliberate text renderer failure')
T.eq(face,0,'failed text draw restores the previous face');T.eq(tones,0,'failed text draw restores tint')
for k,v in pairs(saved)do Font[k]=v end
T.finish('FRLG native map popup standard frame, geometry, font and draw lifetime')
