-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald movie; callback, persistent IDs and saved progress stay hosted.
local Rs=require('src.ui.Gen3RsCredits')
local M=setmetatable({screenId='Gen3EmeraldCredits',isOpaque=true,holdsUIAnchors=true},{__index=Rs});M.__index=M
function M.available(game)
  return require('src.import.Gen3EmeraldCreditsAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3EmeraldCredits,require('src.core.GameVersion').get())
end
function M.new(game,onDone)
  assert(M.available(game))
  local basic=require('compat.gen1-rs.Loader').new('emerald')
  local vars=basic('src.core.game3.constants.emerald.vars').byName
  local session,bindings=require('src.ui.Gen3CreditsSession').new(game,assert(vars.VAR_STARTER_MON))
  local self=setmetatable(require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings=bindings}),M)
  self.onDone,self.session=onDone,session
  self.scene=self.load('src.ui.game3.rse.credits')
  self.state=self.scene.start({session=session,hasRecords=(tonumber(game.save.hallOfFame)or 0)>1,
    onDone=function()self:finish()end})
  return self
end
return M
