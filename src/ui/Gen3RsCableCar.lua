-- Run the pinned native ride; the script resumes only after its final fade.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsCableCar'
function M.available(game)
  return require('src.import.Gen3RsCableCarAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsCableCar,require('src.core.GameVersion').get())
end
function M.new(game,opts)
  assert(M.available(game));opts=opts or{}
  local self=setmetatable({game=game,opts=opts},M)
  local spec=game.data.constants.gen3RsCableCar;local sheets={};local load
  local songs=game.data.constants.gen3RsPresentation.songIds
  local music=require('src.core.Music');local sound=require('src.core.Sound')
  local audio={fadeOutBgm=music.fadeOutM4a}
  function audio.fadeInBgm(id,speed)
    music.stop();local source=music.play(game.data,('SONG_%03X'):format(id))
    music.dsFade(1,16*math.max(1,speed or 1),0);return source
  end
  function audio.playSe(id)return sound.playId(game.data,id)end
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings={
    ['src.core.game3.audio']=audio,
    ['src.core.game3.constants']={of=function()return{require=function(_,family,name)
      return assert((family=='songs'and songs or family=='event_objects'and spec.graphics or{})[name])
    end}end},
    ['src.ui.game3.rse.ow_sheet']={build=function(id)
      if not sheets[id]then
        local row=assert(spec.actors[id]);sheets[id]={sheet=load('src.ui.game3.rse.gba_machine').sheet(row),
          palette=row.palette,paletteTag=row.paletteTag,w=row.w,h=row.h}
      end
      return sheets[id]
    end},
  }})
  load=context.load;self.load,self.canvas=load,context.canvas
  self.scene=load('src.ui.game3.rse.cable_car').new({goingDown=opts.goingDown,
    female=(game.save.player or{}).gender=='girl',requireAssetLayout='rs',
    playerGfxNames={[0]='OBJ_EVENT_GFX_RIVAL_BRENDAN_NORMAL','OBJ_EVENT_GFX_RIVAL_MAY_NORMAL'},
    hikerGfxNames={[0]='OBJ_EVENT_GFX_HIKER','OBJ_EVENT_GFX_CAMPER','OBJ_EVENT_GFX_PICNICKER','OBJ_EVENT_GFX_POOCHYENA'}})
  self.step=load('src.ui.game3.rse.scene_kit').stepper()
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  if self.finishing then return end
  self.step:collect(self.game.input)
  local done=self.step:run(dt,function(input)
    if not self.scene.done then self.scene:frame(input)end
    return self.scene.done or nil
  end)
  if done then
    self.finishing=true
    local callback=self.opts.onDone;self.opts.onDone=nil
    local released=false
    local function release()
      assert(not released,'Native cable car returned twice');released=true
      local stack=self.game.stack
      assert(stack:top()==self,'Native cable-car return must follow its warp transition')
      stack:pop()
    end
    if callback then callback(release)else release()end
  end
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
  require('src.core.Music').dsFade(1,0)
  if self.canvas then self.canvas:release()end
  self.canvas,self.scene,self.step,self.load=nil,nil,nil,nil
end
return M
