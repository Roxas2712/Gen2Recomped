-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Borrow the existing native modal drawers; world and battle composition
-- keep their own passes, surfaces and resource ownership.
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Call=require('src.compat.gen1.SourceCall')
local Scope=require('src.render.GraphicsScope')
local Version=require('src.core.GameVersion')
local M={}
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function drawUi()
 if not Boundary.active('ui.draw')then return false,'UI drawing belongs to its native pass'end
 return Boundary.invoke('ui.draw')
end
M.drawUi=drawUi
function M._wrapped()return M.drawUi~=drawUi end
function M._nativeDrawUi(game,paint,...)
 if not Version.isGen3()or M.drawUi==drawUi then return paint(...)end
 local G=require('src.core.Game3');local view=G.forNative(game)
 if not view then return paint(...)end
 local stack=game.stack;local states=stack.states;local sequence={}
 for i,state in ipairs(states)do sequence[i]=state end
 local data,save,mods,edition=game.data,game.save,game.mods,Version.get()
 local args=pack(...)
 local function admitted()
  if Version.get()~=edition or game.stack~=stack or stack.states~=states
   or game.data~=data or game.save~=save or game.mods~=mods or G.native(view)~=game
   or #states~=#sequence then return false end
  for i,state in ipairs(sequence)do if states[i]~=state then return false end end
  return true
 end
 local result=pack(Scope.call(function()
  return Boundary.dispatch('ui.draw',function()
   if not admitted()then return false,'native UI pass cohort changed'end
   return G._withCallbackOwner(nil,paint,unpack(args,1,args.n))
  end,function()return Call.call(M,'drawUi')end)
 end))
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
function M._nativeStates(game,scene,first,paint)
 if not Version.isGen3()or not M._wrapped()then return paint()end
 local battle=package.loaded['src.core.game3.battle']
 local nativeBattle=battle and battle._screen()
 local battleClass=package.loaded['src.battle.BattleState']
 local begin=first;local last=#scene.states
 for i=first,last do
  local state=scene.states[i]
  if state==game.overworld or state==nativeBattle
   or state and(state.isOverworld or state.isBattleState)
   or battleClass and getmetatable(state)==battleClass then
   if begin<i then M._nativeDrawUi(game,paint,begin,i-1)end
   paint(i,i);begin=i+1
  end
 end
 if begin<=last then return M._nativeDrawUi(game,paint,begin,last)end
end
return M
