-- Run the native RS minute-hand controller over the host's existing RTC save.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsWallClock'
function M.available(game)
  local v=require('src.core.GameVersion').get()
  return require('src.import.Gen3RsClockAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsClock,v)
end
function M.new(game,opts)
  assert(M.available(game));opts=opts or{}
  local self=setmetatable({game=game,opts=opts},M)
  local function time()
    return require('src.ui.Gen3WallClock').read(game.save)
  end
  local rtc={calcLocalTime=function()
    local hour,minute=time();return{hours=hour or 10,minutes=minute or 0}
  end,initLocalTimeOffset=function(_,hour,minute)
    assert(not self.pending,'Native clock confirmed twice')
    assert(not opts.view and hour>=0 and hour<24 and minute>=0 and minute<60)
    self.pending={hour=hour,minute=minute}
  end}
  local context=require('src.ui.Gen3RsSceneContext').new(game,{
    textIR=game.data.constants.gen3RsClock.textIR,bindings={['src.core.game3.rtc']=rtc},
  })
  self.load,self.canvas=context.load,context.canvas
  local Clock=self.load('src.ui.game3.rse.wall_clock')
  self.scene=Clock.new({mode=opts.view and Clock.MODE.VIEW or Clock.MODE.SET,
    gender=(game.save.player or{}).gender=='girl'and'female'or'male',
    session={version=require('src.core.GameVersion').get()},
    frameType=math.max(0,((game.save.options or{}).gen3Frame or 1)-1)})
  self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  self.step:collect(self.game.input)
  local done=self.step:run(dt,function(input)
    if not self.scene.done then self.scene:frame(input)end
    return self.scene.done or nil
  end)
  if not done then return end
  local hour,minute=self.scene:time()
  if self.opts.view then assert(not self.pending,'Viewing a clock must not write its offset')
  else
    assert(self.pending and self.scene.result.confirmed,'Setting a clock needs native YES confirmation')
    self.game.save.gen3Clock={hour=self.pending.hour,minute=self.pending.minute,setAt=os.time()}
  end
  local callback=self.opts.onDone;self.game.stack:pop()
  if callback then callback(hour,minute)end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();self.scene:draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.canvas then self.canvas:release()end
  self.canvas,self.scene,self.step,self.load=nil,nil,nil,nil
end
return M
