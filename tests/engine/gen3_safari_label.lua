package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local B=require('src.battle.Gen3Battle');local F=require('src.render.Font')
local draw,code,advance,width=F.draw,F.drawCode,F.advanceOf,F.width
local glyphs={};F.draw=function(value)T.eq(value,'BAIT')end
F.drawCode=function(n,x,y)glyphs[#glyphs+1]={n,x,y}end
F.advanceOf=function()return 8 end;F.width=function()return 24 end
T.eq(B.drawSafariLabel('{POKEBLOCK}',192,120),40,'native word fits the 48px action cell')
T.same(glyphs,{{0x55,192,120},{0x56,200,120},{0x57,208,120},{0x58,216,120},{0x59,224,120}},
  'original joined cartridge glyphs retain their order and advances')
T.eq(B.drawSafariLabel('BAIT',192,120),24,'ordinary edition labels retain the host font path')
F.draw,F.drawCode,F.advanceOf,F.width=draw,code,advance,width
T.finish('Native Safari Pokeblock compound glyph width and ordinary label forwarding')
