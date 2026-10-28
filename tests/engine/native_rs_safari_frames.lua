-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Panel=require('src.battle.Gen3RsBattlePanel')
local G=require('src.core.Game3');local g=love.graphics
local original=package.loaded['src.core.Game'];local draw,load=g.draw,love.filesystem.load
love.filesystem.load=loadfile
for _,edition in ipairs{'ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.phase='menu';b.menuIndex=2;b.safari={balls=30};b.gen3Safari={edition=edition}
 game.data.constants.gen3SafariNative={dialect='rs',labels={'BALL','POKéBLOCK','GO NEAR','RUN'},
  textIR={prompt={{t='text',s='READY?'},{t='eos'}}}}
 local frames,texts,cursors,images={},{},{},{}
 local art=g.newCanvas(240,48);local chrome={_frameType=0}
 chrome.setFrameType=function(n)chrome._frameType=n end
 chrome.userFrame=function(...)frames[#frames+1]={...}end
 local panel=setmetatable({chrome=chrome,images={action=art},menuColors={},messageColors={},
  font={draw=function(value,...)texts[#texts+1]=value end},
  cursor={draw=function(...)cursors[#cursors+1]={...}end}},Panel)
 b.rsBattlePanel=panel;local before=b.frame;local rolls=0;b.rng=function()rolls=rolls+1;return 0 end
 g.draw=function(image,...)images[#images+1]=image end
 T.eq(panel:draw(b),true);T.eq(#frames,1,'native/source composition paints the Safari frame once')
 T.same(frames[1],{0,18,15,11,4});T.eq(#images,1);T.eq(images[1],art,'native RS panel remains its actual image')
 T.same(texts,{'READY?','BALL','POKéBLOCK','GO NEAR','RUN'})
 T.same(cursors[1],{190,120,42});T.eq(rolls,0);T.eq(b.frame,before)
 b.gen3Safari=nil;frames={};T.eq(panel:draw(b),false);T.eq(#frames,0,'unavailable native Safari retains the older fallback')
 g.draw=draw;if art.release then art:release()end;f.close();G.release()
end
g.draw,love.filesystem.load=draw,load;package.loaded['src.core.Game']=original
T.finish('native RS Safari panel/frame composition, once-only borders and unchanged rules')
