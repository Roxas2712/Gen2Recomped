-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA logical surface fitting and one borrowed native frame-paint boundary.
-- No new game/render loop, render-target allocation or resource ownership.
local Renderer=require('src.render.Renderer')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Call=require('src.compat.gen1.SourceCall')
local Scope=require('src.render.GraphicsScope')
local Version=require('src.core.GameVersion')
local M={W=240,H=160,TILE=8,COLS=30,ROWS=20}
local current
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
function M.fit(w,h)
 local r=Renderer:surfaceRects(M.W,M.H,w,h)
 return r.Ux,r.uox,r.uoy,r.uvpw,r.uvph,r.Uy
end
local function present(game)
 if not current or game==nil or require('src.core.Game3').native(game)~=current.game then
  return nil,'display presentation belongs to its native frame'
 end
 return Boundary.invoke('display.present')
end
M.present=present
function M._nativePresent(game,paint,...)
 if M.present==present then return paint(game,...)end
 if current then return false,'native display frame is already painting'end
 local G=require('src.core.Game3');local view=G.forNative(game)
 if not view then return paint(game,...)end
 local args=pack(...)
 local cohort={game=game,data=game.data,save=game.save,loader=game.mods,stack=game.stack,
  edition=Version.get(),top=game.stack:top(),states=game.stack.states,count=#game.stack.states}
 current=cohort
 local result=pack(pcall(Scope.call,function()
  return Boundary.dispatch('display.present',function()
   if game.data~=cohort.data or game.save~=cohort.save or game.mods~=cohort.loader
      or game.stack~=cohort.stack or G.native(view)~=game
      or Version.generation()~=3 or Version.get()~=cohort.edition
      or game.stack:top()~=cohort.top or game.stack.states~=cohort.states
      or #game.stack.states~=cohort.count then
    return false,'native display cohort changed'
   end
   return paint(game,unpack(args,1,args.n))
  end,function()return Call.call(M,'present',view)end)
 end))
 current=nil
 if not result[1]then error(result[2],0)end
 if not result[2]then error(result[3],0)end
 return unpack(result,3,result.n)
end
return M
