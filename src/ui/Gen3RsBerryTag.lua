-- The original RS tag owns presentation; the host bag owns IDs and cursor.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsBerryTag'
function M.available(game)
  return require('src.import.Gen3RsBerryTagAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsBerryTag,require('src.core.GameVersion').get())
end
function M.new(game,bag,id)
  assert(M.available(game));local list,indices,pos={},{},nil
  for index,row in ipairs(bag.rows)do
    local def=row.id and game.data.items[row.id]
    if def and def.index and def.index>=133 and def.index<=175 then
      list[#list+1]=def.index;indices[#list]=index
      if row.id==id then pos=#list-1 end
    end
  end
  assert(pos,'The selected berry must belong to the authoritative pocket')
  local self=setmetatable({game=game,bag=bag,indices=indices},M)
  local stack={top=function()return nil end,
    push=function(key)assert(key=='rs_berry_tag');self.started=true end,
    pop=function(key)
      assert(key=='rs_berry_tag')
      if self.started and not self.exiting then self.finished=true end
    end}
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings={
    ['src.ui.game3.stack']=stack,
    ['src.core.game3.items_data']={toNumericId=function(item)
      if type(item)=='number'then return item end
      return game.data.items[item]and game.data.items[item].index
    end},
  }})
  self.load,self.canvas=context.load,context.canvas
  self.scene=self.load('src.ui.game3.rs.berry_tag')
  self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
  local function selected(at)
    bag.index=assert(indices[at+1]);local visible=bag:listRows()
    if bag.index<bag.top then bag.top=bag.index
    elseif bag.index>=bag.top+visible then bag.top=bag.index-visible+1 end
  end
  self.scene.show({list=list,pos=pos,session={
    version=require('src.core.GameVersion').get(),
    gender=(game.save.player or{}).gender=='girl'and'female'or'male',
    enigmaBerryNativeBytes=game.save.enigmaBerryNativeBytes,
  },onMove=function(_,at)selected(at)end,onClose=function(at)selected(at)end})
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  self.step:collect(self.game.input)
  local done=self.step:run(dt,function(input)
    self.scene.handleInput({isDown=function(_,key)return input.held[key]end,
      wasPressed=function(_,key)return input.new[key]end})
    self.scene.update();return self.finished or nil
  end)
  if done then self.game.stack:pop()end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1);self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.exiting=true
  local state=self.scene and self.scene._st
  if state then for _,key in ipairs({'textCanvas','enigmaImage'})do
    if state[key]then state[key]:release();state[key]=nil end
  end end
  if self.scene then self.scene.reset()end
  if self.canvas then self.canvas:release()end
  self.scene,self.step,self.canvas,self.load=nil,nil,nil,nil
end
return M
