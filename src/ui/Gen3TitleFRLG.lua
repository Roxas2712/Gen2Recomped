-- Private host adapter for the byte-exact Gen1Recomp FR/LG title controller.
-- Reference attribution and license: compat/gen1-frlg/README.md.
local Assets = require('src.render.Assets')
local Music = require('src.core.Music')
local Screens = require('src.ui.Screens')
local Scope = require('src.render.GraphicsScope')
local PixelCanvas = require('src.render.PixelCanvas')
local Title = {}; Title.__index = Title; Title.isOpaque = true
function Title:wantsFillScale() return true end
function Title:uiSize() return 240,160 end
function Title:sgbPalettes()
  return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}
end
function Title.new(game, opts)
  opts = opts or {}
  return setmetatable({game=game, opts=opts, phase='intro', frame=0}, Title)
end
function Title:enter()
  local rec = assert(self.game.data.constants.gen3FRLGTitle)
  assert(rec.nativeController == 'frlg-native-title-v1', 'Reimport FR/LG native title assets')
  local function image(key)
    local value = assert(rec.images[key], 'Missing native title image: '..key)
    return Assets.image(type(value)=='table' and value.path or value)
  end
  self.state = {titleLogo=image('logo'), titleMon=image('mon'),
    copyrightLayer=image('copyrightOnly'), pressStart=image('pressStart'),
    titleBorder=image('borderNative'), assets={titleFlames=image('flamesNative'),
      titleSlash=image('slash'), titleStreak=rec.effect=='leaves' and image('streak') or nil}}
  local load
  local display = {W=240,H=160}
  function display.composeHardware(opts)
    local Bg, Oam = load('src.core.game3.bg'), load('src.core.game3.oam')
    if opts.clear then love.graphics.clear(unpack(opts.clear)) end
    if opts.animate ~= false then Oam.animateSprites() end
    if opts.build ~= false then Oam.buildOamBuffer(opts.pretOrder) end
    for pri=3,0,-1 do Bg.flushPriority(pri); Oam.flushPriority(pri) end
  end
  local audio = {
    playSong=function(id, opts)
      assert(id==278, 'Unexpected FR/LG title cue')
      if opts and opts.restart then Music.stop() end
      return Music.play(self.game.data, 'SONG_116')
    end,
    playCry=function(species)
      return require('src.core.Sound').playCry(self.game.data, species==3 and 'VENUSAUR' or 'CHARIZARD')
    end,
    fadeOutBgm=Music.fadeOutM4a,
    isBgmStopped=function() return Music.current()==nil end,
  }
  local version=require('src.core.GameVersion').get()
  load = require('compat.gen1-frlg.Loader').new({
    ['src.core.game3.display']=display, ['src.core.game3.audio']=audio,
    ['src.render.PixelCanvas']=PixelCanvas, ['src.core.game3.song_ids']={MUS_TITLE=278},
    ['src.core.GameVersion']={get=function() return version end},
  })
  self.load=load; self.native=load('src.ui.game3.title_screen')
  self.canvas=PixelCanvas.new(240,160,'nearest')
  local ok,why=Scope.call(self.native.enter,self.state)
  if not ok then self:exit(); error(why,0) end
  self.phase,self.frame,self.opened='intro',0,false
end
function Title:exit()
  if self.native and self.state then self.native.leave(self.state) end
  local canvases=self.state and self.state._titleCanvases
  if canvases and canvases.withPress and canvases.withPress~=self.state.copyrightLayer then
    canvases.withPress:release()
  end
  if self.canvas then self.canvas:release() end
  self.state,self.canvas,self.native,self.load=nil,nil,nil,nil
end
function Title:update(dt)
  local result=self.native.update(self.state,self.game.input,dt)
  local t=self.state.title
  self.frame=t.vblanks
  self.phase=t.scene==3 and 'run' or ((t.scene==4 or t.scene==5) and 'leaving' or 'intro')
  if result=='menu' and not self.opened then
    self.opened=true
    Screens.push(self.game,'Gen3MainMenu',{
      onNewGame=self.opts.onNewGame,onContinue=self.opts.onContinue,
      onCancel=function() self:exit(); self:enter() end,
    })
  elseif result=='restart' then
    local game,opts=self.game,self.opts
    assert(game.stack:top()==self)
    game.stack:pop()
    game.stack:push(require('src.ui.Gen3IntroFRLG').new(game,function()
      game.stack:push(Title.new(game,opts))
    end))
  end
end
function Title:draw()
  local ok,why=Scope.call(function()
    local g=love.graphics
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader()
    g.setBlendMode('alpha');g.setColor(1,1,1,1)
    self.native.draw(self.state)
  end)
  assert(ok,why)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(self.canvas,0,0)
end
return Title
