-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Ui=require('src.core.game3.battle.ui')
local Art=require('src.core.game3.battle.ui_ball_art')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
local originalGame=package.loaded['src.core.Game']
local graphics=love.graphics;local image,quad=graphics.newImage,graphics.newQuad
local images,quads={},{}
graphics.newImage=function(path)
 local value={path=path,releases=0,getDimensions=function()return 48,192 end}
 function value:release()self.releases=self.releases+1 end
 images[#images+1]=value;return value
end
graphics.newQuad=function(...)
 local value={cell={...},releases=0}
 function value:release()self.releases=self.releases+1 end
 quads[#quads+1]=value;return value
end
T.eq(Ui.ballQuad(0,0),nil,'no artwork without an admitted battle')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 package.loaded['src.core.Game']=f.game
 local b=f.fresh('TACKLE').battle;b.enter=false;f.game.stack:push(b)
 f.game.data.constants.gen3BallAnim={size=16,frames=3,images={balls='assets/generated/battle/gen3/balls.png'}}
 local beforeImage,beforeQuad=#images,#quads
 local frame=b.frame;local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 local first,firstQuad
 for ball=0,11 do for cell=0,2 do
  local img,q=Ui.ballQuad(ball,cell)
  T.neq(img,nil);T.eq(img.path,require('src.render.Assets').resolve(f.game.data.constants.gen3BallAnim.images.balls))
  T.eq(q.cell[1],cell*16);T.eq(q.cell[2],ball*16);T.eq(q.cell[3],16);T.eq(q.cell[4],16)
  T.eq(q.cell[5],48);T.eq(q.cell[6],192)
  local sameImage,sameQuad=Ui.ballQuad(ball,cell);T.eq(sameImage,img);T.eq(sameQuad,q)
  first,firstQuad=first or img,firstQuad or q
 end end
 T.eq(#images-beforeImage,1,'one owned image serves all twelve ball styles')
 T.eq(#quads-beforeQuad,36);T.eq(b.frame,frame);T.eq(rolls,0,'art queries consume neither battle ticks nor RNG')
 for _,args in ipairs{{-1,0},{12,0},{0,3},{0,-1},{0,0/0},{0,math.huge},{'0',0},{.5,0}}do
  T.eq(Ui.ballQuad(unpack(args)),nil,'malformed cell cannot alias another ball')
 end
 T.eq(#quads-beforeQuad,36,'invalid requests allocate no quads')
 f.game.stack:push({});T.eq(Ui.ballQuad(0,0),first,'covered battle can observe existing art');f.game.stack:pop()
 G._withCallbackOwner('ball_art_A',Ui.ballQuad,1,0)
 G._withCallbackOwner('ball_art_B',Ui.ballQuad,1,0)
 Art._service.releaseOwner(nil,'ball_art_A');T.eq(first.releases,0,'another reader retains art')
 -- The unowned engine reader above also retains this resource.
 Art._service.releaseOwner(nil,'ball_art_B');T.eq(first.releases,0)
 local old=f.game.save;f.game.save={};local changed=Ui.ballQuad(0,0)
 T.neq(changed,first,'new admission cannot lend a retired image')
 T.eq(first.releases,1);T.eq(firstQuad.releases,1)
 f.game.save=old;local replacement=Ui.ballQuad(0,0);T.neq(replacement,first,'retired admission cannot revive old GPU art')
 T.eq(changed.releases,1,'restoring an old save does not revive the intervening image')
 f.game.stack:pop();Art._service.poll();T.eq(replacement.releases,1)
 Art._service.release();T.eq(replacement.releases,1,'release is idempotent')
 f.close();G.release()
end
graphics.newImage,graphics.newQuad=image,quad
package.loaded['src.core.Game']=originalGame
T.eq(Ui.presentationApiVersion,nil,'art cells do not advertise the unfinished drawing protocol')
T.finish('native imported ball cells, owned resource sharing, validation and lifetime')
