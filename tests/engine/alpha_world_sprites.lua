-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.render.PaletteFX')
local V=require('src.core.GameVersion')
local A=require('src.render.Assets')
local oldImage,oldDraw=A.image,love.graphics.draw
A.image=function()return{getDimensions=function()return 16,96 end}end
local S=require('src.render.SpriteRenderer')
local sprite=S.new({id='ALPHA_PROBE',image='alpha-probe',frames=6,poseFrames=6,walker=true,trueColor=true})
local draws={};love.graphics.draw=function(...)draws[#draws+1]={...}end
local methods={
 draw=function()sprite:draw(32,48,4,6,'down',0,false)end,
 walk=function()sprite:draw(32,48,4,6,'right',1,false)end,
 half=function()sprite:draw(32,48,4,6,'down',0,false,true)end,
 fixed=function()sprite:drawFixedFrame(32,48,4,6,2,true)end,
 pose=function()sprite:drawPose(3,32,48,4,6)end,
 tile=function()sprite:drawTile('alpha-probe',28,38,true)end,
}
for _,version in ipairs{'red','crystal'}do
 V.set(version)
 for name,draw in pairs(methods)do
  P.clearTrueColor();P.clearSpriteRedraws();P.setPass('world');draws={}
  draw()
  T.eq(#P.trueColorRects('world'),0,version..' '..name..' never exempts background rectangle')
  T.eq(#P.spriteRedraws(),1,version..' '..name..' queues exact authored image')
  local replay,actual=P.spriteRedraws()[1],draws[1]
  T.eq(replay.image,actual[1],version..' '..name..' keeps texture identity')
  T.eq(replay.quad,actual[2],version..' '..name..' keeps frame/crop identity')
  T.eq(replay.x,actual[3],version..' '..name..' keeps horizontal anchor')
  T.eq(replay.y,actual[4],version..' '..name..' keeps vertical anchor')
  T.eq(replay.sx,actual[6]or 1,version..' '..name..' keeps mirror')
  P.clearTrueColor();P.clearSpriteRedraws();P.setPass('ui');draw()
  T.eq(#P.spriteRedraws(),0,version..' '..name..' does not replay UI over world')
  T.eq(#P.trueColorRects('ui'),1,version..' '..name..' retains UI colour contract')
  P.clearTrueColor();P.clearSpriteRedraws();P.setPass(nil);draw()
  T.eq(#P.spriteRedraws(),0,version..' '..name..' leaves independent 3D paths untouched')
 end
end
-- A fixed native GBC tile already has its own palette and a keyed alpha
-- texture. The foreground replay must not recolour that texture again.
local Tile=require('src.render.TileRenderer')
P.clearSpriteRedraws();P.setPass('world')
local keyed={native=true};local raw={raw=true};local quad={}
local tiles=setmetatable({gbcCtx={},gbcKeyed={[0]=keyed},map={tileAt=function()return 0 end},image=raw,quads={[0]=quad}},{__index=Tile})
tiles:markCellBottomRedraw(2,3,4.5,6.5,{{1,2,3},{4,5,6},{7,8,9},{10,11,12}})
T.eq(#P.spriteRedraws(),2,'both foreground grass tiles replay')
for _,row in ipairs(P.spriteRedraws())do
 T.eq(row.image,keyed,'native grass keeps its baked palette texture')
 T.eq(row.quad,nil,'native keyed tile needs no raw atlas quad')
 T.eq(row.colors,nil,'native keyed tile is not colourized twice')
end
P.clearSpriteRedraws();tiles.gbcCtx=nil;tiles:markCellBottomRedraw(2,3,4.5,6.5,{{1,2,3},{4,5,6},{7,8,9},{10,11,12}})
for _,row in ipairs(P.spriteRedraws())do
 T.eq(row.image,raw,'DMG grass uses original indexed sheet')
 T.eq(row.quad,quad,'DMG grass keeps atlas position')
 T.check(row.keyed and row.colors~=nil,'DMG foreground colour-0 remains transparent')
end
-- Exercise the real entity-to-grass draw order, including the destination
-- cell while a walker straddles a grass boundary.
local Overworld=require('src.world.OverworldController')
P.clearTrueColor();P.clearSpriteRedraws();P.setPass('world')
local entity={cellX=2,cellY=3,targetX=3,targetY=3,
 draw=function()sprite:draw(32,48,4,6,'down',0,false)end}
local world={player=entity,map=tiles.map,drawGen3Grass=function()return false end,
 gen3GrassFrame=function()end}
world.map.renderer=tiles;world.map.isGrassCell=function()return true end
tiles.drawCellBottom=function()end -- graphics IO already covered by GPU fixture
Overworld._worldDrawEntity(world,entity,{x=4,y=6},6,nil,nil,1,
 {{255,255,255},{0,0,255},{0,255,0},{0,0,0}},nil,nil,function()return 0 end)
T.eq(#P.spriteRedraws(),5,'one actor plus both tiles in current and destination grass cells')
T.eq(P.spriteRedraws()[1].image,sprite.image,'foreground replay follows the actor')
for i=2,5 do T.eq(P.spriteRedraws()[i].image,raw,'current/destination grass remains in front')end
love.graphics.draw,A.image=oldDraw,oldImage
P.setPass(nil)
T.finish('alpha-safe world sprites, exact poses and foreground grass replay')
