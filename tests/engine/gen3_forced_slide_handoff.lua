-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local W=require('src.world.OverworldController')
local C=require('src.world.Collision');local original,oldMove=V.get(),C.canMove
local permitted=true;C.canMove=function()return permitted end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  local row={way='down',slide=true};local ice=true
  local p={cellX=3,cellY=13,facing='right'}
  local w=setmetatable({player=p,entities={p},iceSlide='up',
    map={forcedMovementAt=function()return row end}},{__index=W})
  function w:scriptMove(actor,dir,n,done,keep,rate)
    self.last={actor=actor,dir=dir,n=n,done=done,keep=keep,rate=rate}
  end
  function w:isIceCell()return ice end
  T.eq(w:checkGen3Forced(),true);T.eq(w.iceSlide,'down','arrow replaces stale opposite ice direction')
  T.eq(w.last.actor,p);T.eq(w.last.dir,'down');T.eq(w.last.keep,true)
  row=nil
  T.eq(w:checkGen2Ice(),true,'slippery bridge retains native movement owner')
  T.eq(w.last.dir,'down','bridge continues actual travel rather than facing')
  T.eq(w.last.keep,true);T.eq(p.facing,'right','locked sprite does not turn on bridge')
  row={way='left',slide=true};T.eq(w:checkGen3Forced(),true);T.eq(w.iceSlide,'left')
  row=nil;T.eq(w:checkGen2Ice(),true);T.eq(w.last.dir,'left')
  permitted=false;T.eq(w:checkGen2Ice(),false);T.eq(w.iceSlide,nil,'collision ends the slide')
  permitted=true;ice=false;w.iceSlide='down';T.eq(w:checkGen2Ice(),false);T.eq(w.iceSlide,nil,'ordinary floor clears travel direction')
  p.surfing=true;row={way='down',slide=true};T.eq(w:checkGen3Forced(),false,'surf currents keep their own handler')
end
V.set('crystal')
local p={cellX=1,cellY=1,facing='up'}
local w=setmetatable({player=p,iceSlide='left',map={},entities={}},{__index=W})
function w:isIceCell()return true end
function w:scriptMove(_,dir,_,_,keep)self.dir,self.keep=dir,keep end
T.eq(w:checkGen2Ice(),true);T.eq(w.dir,'left');T.eq(w.keep,nil);T.eq(p.facing,'left','Johto facing rule retained')
C.canMove=oldMove;V.set(original)
T.finish('Gen3 directional slide to slippery crossing handoff, facing, collision and Gen2 isolation')
