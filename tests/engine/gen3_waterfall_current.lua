-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local G=require('src.core.Game')
local W=require('src.world.OverworldController');local C=require('src.world.Collision')
local oldEdition,oldCollision=V.get(),C.canMove
local permitted=true
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local fixture=require('tests.checkpoint_fixture').boot(edition,3)
  G.data.constants.gen3Waterfall={behaviour=19}
  C.canMove=function()return permitted end
  local behaviour,current,row=19,nil,{way='down'}
  local p={cellX=20,cellY=60,facing='up',surfing=true}
  local w=setmetatable({player=p,entities={p},map={
    currentAt=function()return current end,
    cellBehaviour=function()return behaviour end,
    forcedMovementAt=function()return row end,
  }},{__index=W})
  function w:scriptMove(actor,dir,n,done)
    self.last={actor=actor,dir=dir,n=n,done=done}
  end
  function w:onStepComplete()self.completed=true end
  T.eq(w:checkGen3Current(),true,edition..' waterfall uses native forced-movement row')
  T.eq(w.gen3Current,'down');T.eq(p.facing,'down')
  if w.last then
    T.eq(w.last.actor,p);T.eq(w.last.dir,'down');T.eq(w.last.n,1)
    w.last.done();T.eq(w.completed,true,'current retains step-completion owner')
  end
  permitted=false;w.last=nil
  T.eq(w:checkGen3Current(),false,'rock stops the descent')
  T.eq(w.gen3Current,nil);T.eq(w.last,nil)
  permitted=true;behaviour=16;w.last=nil
  T.eq(w:checkGen3Current(),false,'ordinary sea ends descent even if a floor row exists')
  T.eq(w.gen3Current,nil);T.eq(w.last,nil)
  current='left';T.eq(w:checkGen3Current(),true,'existing sea current still owns direction')
  T.eq(w.last.dir,'left');T.eq(p.facing,'left')
  p.surfing=false;w.last=nil
  T.eq(w:checkGen3Current(),false,'land movement stays with its existing handler')
  T.eq(w.last,nil)
  p.surfing=true;current=nil;behaviour=19;row=nil
  T.eq(w:checkGen3Current(),false,'missing imported movement is not invented')
  row={way='down'};G.data.constants.gen3Waterfall=nil
  T.eq(w:checkGen3Current(),false,'legacy imports keep their existing terrain rules')
  G.data.constants.gen3Waterfall={behaviour=19}
  local mon={species='FIXMON_A'};local shown,continuation,climbs
  p.facing='up'
  function p:facingCell()return self.cellX,self.cellY-1 end
  function w:partyKnows()return mon end
  function w:gen3FieldText()return 'Use WATERFALL?' end
  function w:gen3ShowFieldMove(member,done)shown,continuation=member,done end
  function w:gen3UseWaterfall(x,y,b)
    climbs=(climbs or 0)+1;T.eq(x,p.cellX);T.eq(y,p.cellY-1);T.eq(b,19)
  end
  T.eq(w:tryWaterfallOW(),true)
  local prompt=G.stack:top();prompt.choice(false)
  T.eq(shown,nil,'NO does not announce or climb')
  prompt.choice(true)
  T.eq(shown,mon,'A interaction announces the actual HM user')
  T.eq(climbs,nil,'ascent waits for its field-move presentation')
  T.eq(type(continuation),'function')
  continuation();T.eq(climbs,1,'presentation hands back to the existing climb')
  C.canMove=oldCollision;fixture.close()
end
V.set('crystal')
local w=setmetatable({player={surfing=true},map={currentAt=function()error('Gen2 queried Gen3 terrain')end}},{__index=W})
T.eq(w:checkGen3Current(),false,'other generations retain their movement')
C.canMove=oldCollision;V.set(oldEdition)
T.finish('GBA waterfall descent, current direction, collision, landing and generation isolation')
