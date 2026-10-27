-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Font=require('src.render.Font');local F=require('src.ui.game3.frlg_font')
local V=require('src.core.GameVersion');local Assets=require('src.render.Assets')
local oldImage,oldDraw,oldVersion=Assets.image,Font.draw,V.get()
Assets.image=function()return{getDimensions=function()return 128,128 end}end
local function code(cmd,n)return string.char(0xfc,cmd,n)end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 V.set(edition)
 Font.load({font={pages={main={image='QA_FONT',base=0,glyphWidth=8,glyphHeight=8,advance=4}},
  faces={small={image='QA_SMALL',base=0,glyphWidth=8,glyphHeight=8,advance=3}},
  charmap={{seq='A',code=1},{seq='é',code=2},{seq='<PK>',code=3}}}})
 local rows={};Font.draw=function(g,x,y)rows[#rows+1]={g,x,y};return Font.width(g)end
 local pp=code(0x11,2)..code(0x14,6)..'Aé<PK>'
 T.eq(F.measure(pp),20,'padding and fixed minimum cells include complete Unicode/ligature glyphs')
 T.eq(F.draw(pp,10,20),20);T.same(rows,{{'A',12,20},{'é',18,20},{'<PK>',24,20}})
 rows={};T.eq(F.measure(pp,{small=true}),20);T.eq(F.draw(pp,0,0,{small=true,maxWidth=10}),20)
 T.same(rows,{{'A',2,0}},'width clipping excludes ink, not the native cursor advance')
 rows={};local moved='A'..code(0x13,20)..'é'..code(0x13,2)..'<PK>'
 T.eq(F.measure(moved),28);T.eq(F.draw(moved,0,0),28)
 T.same(rows,{{'A',0,0},{'é',20,0},{'<PK>',24,0}},'CLEAR_TO never moves the pen backwards')
 rows={};local shifts='A'..code(0x0d,12)..code(0x0e,7)..'é'..code(0x12,2)..'A'
 T.eq(F.draw(shifts,3,4),6);T.same(rows,{{'A',3,4},{'é',15,11},{'A',5,11}})
 rows={};local lines=code(0x14,6)..'A\né'
 T.eq(F.measure(lines,{linePitch=16}),6);T.eq(F.draw(lines,1,2,{linePitch=16}),6)
 T.same(rows,{{'A',1,2},{'é',1,18}})
 rows={};T.eq(F.draw(pp,0,0,{limitChars=1}),8);T.same(rows,{{'A',2,0}})
 rows={};T.eq(F.measure('Aé',{letterSpacing=2}),10);T.eq(F.draw('Aé',0,0,{letterSpacing=2}),10)
 T.same(rows,{{'A',0,0},{'é',6,0}},'ordinary proportional labels keep their spacing')
 rows={};T.eq(F.measure(pp,{letterSpacing=3}),20,'native fixed-width control owns cell spacing')
 local shader={};love.graphics.setShader(shader);love.graphics.setColor(.2,.3,.4,.5)
 for _,bad in ipairs{'A'..string.char(0xfc),'A'..string.char(0xfc,0x11),'A'..code(0x99,1)}do
  T.raises(function()F.measure(bad)end,'native text pen control')
  T.raises(function()F.draw(bad,0,0,{small=true})end,'native text pen control')
 end
 T.eq(#rows,0,'malformed controls are rejected before any draw')
 T.eq(Font.advanceOf(1),4);T.eq(love.graphics.getShader(),shader)
 local r,g,b,a=love.graphics.getColor();T.eq(r,.2);T.eq(g,.3);T.eq(b,.4);T.eq(a,.5)
 Font.draw=function()error('owned pen paint failure')end
 T.raises(function()F.draw(pp,0,0,{small=true})end,'owned pen paint failure')
 T.eq(Font.advanceOf(1),4);T.eq(love.graphics.getShader(),shader)
end
Assets.image=oldImage;Font.draw=oldDraw;V.set(oldVersion)
T.finish('shared native pen measurement and rendering, complete glyphs, bounds and error restoration')
