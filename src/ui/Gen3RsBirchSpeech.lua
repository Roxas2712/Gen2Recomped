-- Native RS Birch/naming controllers in a private require/RNG/render scope.
local M={};M.__index=M
M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsBirchSpeech'
function M.available(data,version)
  version=version or require('src.core.GameVersion').get()
  local s=data and data.constants and data.constants.gen3RsBirch
  return (version=='ruby'or version=='sapphire')and type(s)=='table'and s.format==1 and s.version==version
end
function M.new(game,opts)
  assert(M.available(game.data))
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game),M)
  self.onDone=type(opts)=='function'and opts or type(opts)=='table'and opts.onDone
  local speed=(game.save.options or {}).textSpeed or 3
  self.scene=self.load('src.ui.game3.rs.birch_speech').new({textSpeed=speed>=5 and 0 or speed>=3 and 1 or 2,
    frameType=math.max(0,((game.save.options or {}).gen3Frame or 1)-1)})
  return self
end
function M:enter()require('src.mods.Runtime').emit('intro.birch_speech.started',{speech=self})end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  local result=self.scene:update(self.game.input,dt)
  if type(result)~='table'then return end
  assert(result.action=='new_game'and result.fieldCallback=='truck')
  local p=self.game.save.player
  p.name=result.name;p.gender=result.gender==1 and 'girl'or 'boy'
  p.rival=result.gender==1 and 'BRENDAN'or 'MAY'
  require('src.mods.Runtime').emit('intro.birch_speech.finished',{speech=self,answers={name=p.name,gender=p.gender}})
  local done=self.onDone
  self.game.stack:pop()
  if done then done()end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1)
    self.scene:draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.scene then self.scene:destroy()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas=nil,nil,nil
end
return M
