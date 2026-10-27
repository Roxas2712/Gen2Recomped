-- The authored mailbox edits a private candidate; transfers commit together.
local M={};M.__index=M;M.isOpaque=false;M.holdsUIAnchors=true;M.screenId='Gen3RsMailbox'
local S=require('src.core.SaveSerializer')
local function state(self)return S.encode({mail=self.session.mail,party=self.session.party,bag=self.bag})end
function M.new(game,opts)
  local View=require('src.ui.Gen3RsMailView');assert(View.available(game))
  local self=setmetatable({game=game,opts=opts or{}},M)
  self.model=require('src.inventory.Gen3RsMail').new(game);assert(self.model.valid,self.model.reason)
  self.session=assert(self.model:project());self.bag=self.model:bagCopy()
  self.session.bag=self.bag;self.expected=self.model:fingerprint()
  local picker
  local context=View.context(game,{
    ['src.core.game3.mail']=self.model.native,
    ['src.core.game3.bag']={canAdd=function(bag,n,q)
      assert(bag==self.bag);local copy=self.model:bagCopy()
      return require('src.inventory.Bag').add(copy,assert(self.model.items[n]),q,game.data)
    end,add=function(bag,n,q)
      assert(bag==self.bag)
      return require('src.inventory.Bag').add(bag,assert(self.model.items[n]),q,game.data)
    end},
    ['src.ui.game3.stack']={push=function(id)assert(id=='rse_mailbox')end,
      pop=function(id)assert(id=='rse_mailbox');if not self.exiting then self.finished=true end end},
    ['src.ui.game3.rs.mail_reader']={read=function(record,options)
      game.stack:push(View.new(game,{kind='reader',record=record,onDone=options.onClose}))
    end},
    ['src.ui.game3.party_menu']={show=function(options)
      assert(not picker)
      picker=require('src.ui.Gen3PartyMenu').new(game,{pickOnly=true,keepOpen=true,
        onSwitch=function(mon)
          if require('src.pokemon.Party').isEgg(mon)then return end
          for i,host in ipairs(game.save.party or{})do if host==mon then
            self:mutate(function()options.onSelect(i)end);break
          end end
        end,onCancel=function()picker=nil;if options.onClose then options.onClose()end end})
      game.stack:push(picker)
    end,close=function()if picker then picker:close()end end},
  })
  self.load,self.canvas=context.load,context.canvas
  self.ui=self.load('src.ui.game3.rse.mailbox')
  self.ui.show({session=self.session,onClose=function()self.finished=true end})
  self.before=state(self) -- Original compaction is a read-only private view.
  self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
  return self
end
function M:mutate(fn)
  if self.model:fingerprint()~=self.expected then self.finished=true;return false end
  fn()
  local after=state(self)
  if after~=self.before then
    self.model:commit(self.session,self.bag)
    self.expected=self.model:fingerprint();self.before=after
  end
  return true
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  self.step:collect(self.game.input)
  local done=self.step:run(dt,function(input)
    self:mutate(function()self.ui.handleInput({wasPressed=function(_,k)return input.new[k]end})end)
    return self.finished or nil
  end)
  if done then local cb=self.opts.onDone;self.opts.onDone=nil;self.game.stack:pop();if cb then cb()end end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self.ui.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.exiting=true;if self.ui then self.ui._onClose=nil;self.ui.reset()end
  if self.canvas then self.canvas:release()end
  self.load,self.canvas,self.ui,self.step=nil,nil,nil,nil
end
return M
