-- Native RS choice presentation; callback returns the host's stable species ID.
local M={};M.__index=M
M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsStarterSelect'
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsStarter
  return (v=='ruby'or v=='sapphire')and type(s)=='table'and s.format==1 and s.version==v and s
end
function M.new(game,list,onChoose)
  local spec=assert(M.available(game));local byNumber={}
  assert(#list==3)
  for i,row in ipairs(spec.species)do
    assert(list[i]==row.id,'Native RS starter grant order changed');byNumber[row.index]=row
  end
  local pokemon={_names=true}
  function pokemon.name(number)return assert(byNumber[number]).name end
  function pokemon.national(number)return assert(byNumber[number]).dex end
  function pokemon.frontPic(number)
    return {image=require('src.render.Assets').image(assert(spec.pics[number]))}
  end
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{textIR=spec.textIR,bindings={
    ['src.core.Strings']=require('src.core.Strings'),['src.core.game3.pokemon']=pokemon,
  }}),M)
  self.spec=spec;self.species=list;self.onChoose=onChoose
  local kit=self.load('src.ui.game3.rse.scene_kit');local original=kit.loadLua
  kit.loadLua=function(path)
    if path=='data/generated/gba/pokemon/dex.lua'then return spec.dex end
    return original(path)
  end
  self.step=kit.stepper()
  self.scene=self.load('src.ui.game3.rse.starter_choose').new({frameType=math.max(0,((game.save.options or {}).gen3Frame or 1)-1)})
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  self.step:collect(self.game.input)
  local done=self.step:run(dt,function(inp)
    if not self.scene.done then self.scene:frame(inp)end
    return self.scene.done or nil
  end)
  if not done then return end
  local index=self.scene.result;assert(index==0 or index==1 or index==2)
  local species=assert(self.species[index+1]);local callback=self.onChoose;self.onChoose=nil
  self.game.stack:pop()
  if callback then callback(species)end
end
function M:draw()
  local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1)
    self.scene:draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.canvas then self.canvas:release()end
  self.canvas,self.scene,self.step,self.load=nil,nil,nil,nil
end
return M
