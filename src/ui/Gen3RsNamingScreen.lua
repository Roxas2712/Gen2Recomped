-- Native RS nickname controller over the authoritative host Pokemon/callback.
local M={};M.__index=M
M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsNamingScreen'
function M.available(game,opts)
  return opts and opts.kind=='mon' and type(opts.mon)=='table'
    and require('src.ui.Gen3RsBirchSpeech').available(game and game.data) or false
end
local function manifest()
  local chunk=assert(love.filesystem.load('data/generated/gba/naming/manifest.lua'),'Missing native RS naming manifest')
  setfenv(chunk,{});return chunk()
end
function M.new(game,opts)
  assert(M.available(game,opts))
  local mon=opts.mon;local def=assert(game.data.pokemon[mon.species],'Unknown named Pokemon')
  local man=manifest();local version=require('src.core.GameVersion').get()
  assert(man.game==version and man.layout=='rs','Mixed native RS naming cache')
  local pokemon={picSpecies=function(n)return n end}
  local icon
  function pokemon.icon(number)
    assert(number==def.index,'Naming icon belongs to another Pokemon')
    if not icon then
      local image,h=require('src.ui.Gen3PartyMenu').iconFor({game=game},mon)
      assert(image,'Missing native named Pokemon icon')
      local w,total=image:getDimensions();h=math.min(h or total,total)
      icon={image=image,w=w,h=h,quads={[0]=love.graphics.newQuad(0,0,w,h,w,total)}}
    end
    return icon
  end
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{
    bindings={['src.core.game3.pokemon']=pokemon}}),M)
  self.scene=self.load('src.ui.game3.naming')
  local template='CAUGHT_MON';local row=assert(self.scene.templateFromManifest(man,template))
  local function finish(name)
    if self.closed then return end
    self.closed=true;game.stack:pop()
    if opts.onDone then opts.onDone(name)end
  end
  self.state=self.scene.open({template=template,title=(def.name or mon.species)..assert(row.title),
    maxLen=opts.maxLen or row.maxChars,species=assert(def.index),personality=mon.personality or 0,
    monGender=require('src.pokemon.Pokemon').genderOf(game.data,mon),
    initialText=mon.nickname or '',seed=opts.default or mon.nickname,onDone=finish,game=game})
  require('src.compat.gen1.NativeModalObservation').capture(self,game)
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  if self.closed then return end
  local scene=self.scene;scene.handleInput(self.game.input)
  if not self.closed then scene.update(dt or 1/60)end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1)
    self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true
  if self.scene then self.scene.dismiss()end
  if self.canvas then self.canvas:release()end
  self.state,self.scene,self.load,self.canvas=nil,nil,nil,nil
end
return M
