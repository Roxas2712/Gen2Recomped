-- Native RS script choices; the host script remains the sole result owner.
local M={};M.__index=M;M.isOpaque=false;M.holdsUIAnchors=true;M.screenId='Gen3RsChoice'
function M.available(game)
  return require('src.ui.Gen3RsStarterSelect').available(game)and true or false
end
function M.new(game,labels,opts)
  assert(M.available(game));opts=opts or {}
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{bindings={
    ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
  }}),M)
  self.scene=self.load('src.ui.game3.choice')
  -- This private context always represents RS, including the original RS
  -- width calculation, frame, text and outline cursor. Keep reference bytes.
  self.scene.fieldLayout=function()return 'rs'end
  local function close(value)
    if self.closed then return end
    self.closed=true;game.stack:pop()
    if opts.onAnswer then opts.onAnswer(value)end
  end
  self.scene.multi(labels,opts.default or 0,close,{
    left=(tonumber(opts.left)or 0)+1,top=(tonumber(opts.top)or 0)+1,
    cols=math.max(1,tonumber(opts.cols)or 1),ignoreBPress=opts.ignoreB==true or tonumber(opts.ignoreB)==1})
  self.index=self.scene.cursor
  return self
end
function M.yesNo(game,onChoose,opts)
  assert(M.available(game));opts=opts or{}
  local rows=assert(game.data.constants.gen3RsBirch.textLists.gMenuYesNoItems)
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{textIR={
    gText_Yes=assert(rows[0]),gText_No=assert(rows[1]),
  },bindings={
    ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
    ['src.ui.game3.battle_chrome']={layout=function()return 'rs'end},
  }}),M)
  self.scene=self.load('src.ui.game3.choice');self.scene.fieldLayout=function()return 'rs'end
  self.yesNo=true
  local style=M.yesNoStyle(game)
  self.scene.yesNo(function(yes)
    if self.closed then return end
    self.closed=true;game.stack:pop();onChoose(yes)
  end,{left=style=='party'and 23 or 20,top=8})
  if style=='battle'then self.scene.style='battle';self.scene.left,self.scene.top=24,9 end
  if style=='bag_machine'then self.scene.left,self.scene.top=7,7 end
  self.scene.cursor=opts.defaultNo and 2 or 1
  self.index=self.scene.cursor
  if opts.noSound then self.load('src.core.game3.audio').playSe=function()end end
  return self
end
function M.yesNoStyle(game)
  local states=game.stack and game.stack.states or{}
  local Party=package.loaded['src.ui.Gen3PartyMenu']
  local Battle=package.loaded['src.battle.BattleState']
  for i=#states,1,-1 do
    local s=states[i]
    if s.rsMachineBag then return 'bag_machine'end
    if Party and getmetatable(s)==Party then return 'party'end
    if Battle and getmetatable(s)==Battle then return 'battle'end
  end
  return 'field'
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()
  if self.closed then return end
  local input=self.game.input;local scene=self.scene
  if input:wasPressed('up')then scene.move(-1,0)
  elseif input:wasPressed('down')then scene.move(1,0)
  elseif not self.yesNo and input:wasPressed('left')then scene.move(0,-1)
  elseif not self.yesNo and input:wasPressed('right')then scene.move(0,1)
  elseif input:wasPressed('a')then scene.confirm()
  elseif input:wasPressed('b')then scene.cancel()end
  self.index=scene.cursor
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
  if self.canvas then self.canvas:release()end
  self.scene,self.canvas,self.load=nil,nil,nil
end
return M
