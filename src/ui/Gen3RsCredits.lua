-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Host save/callback views over the byte-exact native RS credits controller.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsCredits'
function M.available(game)
  return require('src.import.Gen3RsCreditsAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsCredits,require('src.core.GameVersion').get())
end
function M.new(game,onDone)
  assert(M.available(game))
  local data,save=game.data,game.save
  local byNumber,byNational={},{}
  for id,row in pairs(data.pokemon)do
    if row.index then byNumber[row.index]={id=id,def=row}end
    if row.dex and row.dex>=1 and row.dex<=386 and row.index
      and(not byNational[row.dex]or row.index<byNational[row.dex])then byNational[row.dex]=row.index end
  end
  local function row(n)return assert(byNumber[tonumber(n)],'Unknown native credits species '..tostring(n))end
  local hostDex=save.pokedex or{}
  local player=save.player or{}
  local session={version=require('src.core.GameVersion').get(),
    gender=(player.gender=='girl'or player.gender=='female'or player.gender==1 or player.female==true)and 1 or 0,
    dex={unownPersonality=hostDex.unownPersonality,spindaPersonality=hostDex.spindaPersonality}}
  for _,kind in ipairs{'caught','owned'}do
    local bits=hostDex[kind]or(kind=='caught'and hostDex.owned)or{}
    session.dex[kind]=setmetatable({},{__index=function(_,n)
      local r=byNumber[n];return r and(bits[r.id]==true or bits[r.id]==1)or false
    end})
  end
  local basic=require('compat.gen1-rs.Loader').new(session.version)
  local native=require('compat.gen1-rs.Constants').new(basic)
  local starter=(save.gen3Vars or{})[assert(native:var('VAR_STARTER_MON'))]or 0
  local self
  local bindings={
    ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
    ['src.core.game3.rse.init']={var=function(name)assert(name=='VAR_STARTER_MON');return starter end},
    ['src.core.game3.dex']={isCaught=function(d,n)return d.caught[n]==true or d.owned[n]==true end,
      defaultPersonality=function(d,n)
        local nat=row(n).def.dex
        return tonumber(nat==201 and d.unownPersonality or nat==327 and d.spindaPersonality)or 0
      end},
    ['src.core.game3.pokemon']={speciesFromNational=function(n)return byNational[n]end,
      national=function(n)return row(n).def.dex end,
      dexFrontPic=function(n,pid)
        local r=row(n);local path=require('src.pokemon.Sprites').path(data,r.id,'front',{
          kind='dex',mon={species=r.id,personality=pid or 0,shiny=false}})
        return path and{image=require('src.render.Assets').image(path)}or nil
      end},
  }
  self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings}),M)
  self.onDone,self.session=onDone,session
  self.scene=self.load('src.ui.game3.rs.credits')
  self.state=self.scene.start({session=session,hasRecords=(tonumber(save.hallOfFame)or 0)>1,
    onDone=function()self:finish()end})
  return self
end
function M:finish()
  if self.closed then return end
  self.closed=true;local cb=self.onDone;self.onDone=nil
  assert(self.game.stack:top()==self,'Native credits lost their host owner')
  self.game.stack:pop();if cb then cb()end
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()
  if self.closed then return end
  self.scene.handleInput(self.game.input);self.scene.update()
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true
  if self.scene then self.scene.reset()end
  for _,img in pairs(self.state and self.state.images or{})do if img.release then img:release()end end
  if self.load then self.load('src.core.game3.gba_ppu').clearCache()end
  if self.canvas then self.canvas:release();self.canvas=nil end
end
return M
