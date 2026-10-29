-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A classic battle decorator submits its world image while drawing its UI
-- canvas. Exercise the real Game compositor, not just screen admission.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Game=require('src.core.Game')
local Battle=require('src.battle.BattleState')
local Stack=require('src.core.StateStack')
local R=require('src.render.Renderer')
local UI=require('src.render.ScreenSpaceUI')
local Pokemon=require('src.pokemon.Pokemon')
local Save=require('src.core.SaveData')
local g=love.graphics
local oldGame,oldVersion=package.loaded['src.core.Game'],V.get()
local nativeDraw,nativeWindow=Battle.draw,Battle.drawWidescreen
local gpuDraw=g.draw
R:init()
for _,version in ipairs{'gold','silver','crystal','prism','polishedcrystal','red','firered','emerald'}do
 V.set(version)
 local data=T.fixtures.fresh();require('src.render.Font').load(data)
 local save=Save.newGame();save.party={Pokemon.new(data,'FIXMON_A',30)}
 local stack=setmetatable({},{__index=Stack});stack:init()
 local game=setmetatable({data=data,save=save,stack=stack,renderer=R,mods={exports={}}},{__index=Game})
 package.loaded['src.core.Game']=game
 local b=Battle.newWild(game,'FIXMON_C',20);b.enter=false
 b.colorMode=function()return false end
 stack:push(b)
 local arena=g.newCanvas(800,720)
 local calls,blits=0,0
 Battle.draw=function(self)
  calls=calls+1;T.eq(self,b,'classic decorator retains the native battle identity')
  T.eq(g.getCanvas(),R.canvas,'classic decorator runs on the UI canvas before composition')
  R:setWorldOverride(arena);g.clear(0,0,0,0)
  return nativeDraw(self)
 end
 T.eq(b:drawsWidescreen(),false,'a classic decorator does not claim the late window protocol')
 T.eq(UI.hasNativeStack(stack,stack,1,nil),false,'implicit window stack cannot bypass the classic owner')
 g.draw=function(image,...)
  if image==arena then blits=blits+1;T.eq(calls,1,'world override was submitted before its actual blit')end
  return gpuDraw(image,...)
 end
 local frame,hp,mon=b.frame,save.party[1].hp,save.party[1]
 Game._draw(game)
 T.eq(calls,1,'actual Game compositor invokes the classic decorator exactly once')
 T.eq(blits,1,'actual Renderer consumes the submitted world canvas in the same frame')
 T.eq(b.frame,frame,'drawing cannot advance native combat')
 T.eq(save.party[1],mon,'drawing cannot replace the native party owner')
 T.eq(mon.hp,hp,'drawing cannot change native HP')
 T.eq(R.worldOverride,nil,'frame cleanup retires the borrowed override')
 if V.isGen2()then
  local windowCalls=0
  Battle.drawWidescreen=function(self,...)
   windowCalls=windowCalls+1;return nativeWindow(self,...)
  end
  T.eq(b:drawsWidescreen(),true,'an explicit native window decorator retains priority')
  calls,blits=0,0;Game._draw(game)
  T.eq(windowCalls,1,'explicit native window owner executes exactly once')
  T.eq(calls,0,'explicit native owner does not also replay the classic decorator')
  Battle.drawWidescreen=nativeWindow
 end
 Battle.draw=nativeDraw;g.draw=gpuDraw
 T.eq(b:drawsWidescreen(),V.isGen2(),'unloading a classic decorator restores native window admission')
 if arena.release then arena:release()end
end
Battle.draw,Battle.drawWidescreen=nativeDraw,nativeWindow
g.draw=gpuDraw;package.loaded['src.core.Game']=oldGame;V.set(oldVersion)
T.finish('actual classic draw owner, same-frame world override and native Gen2 window coexistence')
