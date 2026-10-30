-- RS party_menu.c / pokemon_menu.c return machine use to the original bag.
local M={}
function M.active()
  local v=require('src.core.GameVersion').get();return v=='ruby'or v=='sapphire'
end
function M.fromBag(game,battle,id,list)
  local item=game.data.items and game.data.items[id]
  return M.active()and not battle and item and item.machine
    and getmetatable(list)==require('src.ui.Gen3BagMenu')or false
end
-- item_use.c:689-722: boot, PC login cue, contained move and the (7,7)
-- teaching question precede the party picker. NO/B leaves the same bag open.
function M.prompt(game,battle,id,list,onYes)
  if not M.fromBag(game,battle,id,list)then return false end
  local version=require('src.core.GameVersion').get()
  local spec=game.data.constants.gen3RsBag
  if not require('src.import.Gen3RsBag').machineReady(spec,version)then return false end
  local TextBox=require('src.render.TextBox')
  local function box(text,done,opts)
    opts=opts or{};opts.box={tx=2,ty=15,tw=26,th=4}
    opts.maxPixels=208;opts.uiWidth,opts.uiHeight=240,160
    opts.textX,opts.line1Y,opts.line2Y=16,120,136
    opts.softWrap=false;opts.promptOnlyWhenWaiting=true
    opts.scrollDistance,opts.scrollStep=16,2
    local b=TextBox.new(game,text,done,opts);b.rsMachineBag=list;b.holdsUIAnchors=true
    local context=require('src.ui.Gen3RsSceneContext').new(game)
    local chrome=context.load('src.ui.game3.chrome')
    b.wantsFillScale=function()return true end;b.wantsEdgeBleed=function()return false end
    function b:draw()
      local g=love.graphics;local Font=require('src.render.Font')
      local ok,why=require('src.render.GraphicsScope').call(function()
        g.setCanvas(context.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
        -- ItemUseOutOfBattle_TMHM erases the old description at tile (0,13).
        g.setColor(1,1,1,1);g.rectangle('fill',0,104,104,56);chrome.dialogueFrame()
        g.setScissor(16,120,208,32);g.setColor(0,0,0,1)
        local lastX,lastY
        for i,line in ipairs(self.shown)do
          local x,y=16,120+(i-1)*16
          for _,code in ipairs(line)do Font.drawCode(code,x,y);x=x+Font.advanceOf(code)end
          lastX,lastY=x,y
        end
        if self.waiting and lastX then chrome.promptArrow(lastX,lastY,self.blink)end
      end)
      if not ok then error(why,0)end
      g.setColor(1,1,1,1);g.draw(context.canvas,0,0)
    end
    function b:exit()if context.canvas then context.canvas:release();context.canvas=nil end end
    return b
  end
  local item=game.data.items[id];local move=assert(game.data.moves[item.machine.move]).name
  local function ask()
    local text=spec.machineText.gOtherText_ContainsMove:gsub('{VAR1}',function()return move end)
    game.stack:push(box(text,nil,{choice=function(yes)if yes then onYes()end end}))
  end
  local text=spec.machineText[item.machine.kind=='HM'and'gOtherText_BootedHM'or'gOtherText_BootedTM']
  local boot=box(text,ask)
  local update=boot.update
  function boot:update(dt)
    update(self,dt)
    if self.done and not self.rsBootCue then
      self.rsBootCue=true
      require('src.core.Sound').playId(game.data,assert(game.data.constants.gen3RsPresentation.songIds.SE_PC_LOGIN))
    end
  end
  game.stack:push(boot);return true
end
function M.learnedOptions(game)
  if not M.active()then return nil end
  return {auto={wait=true,sound=function()
    return require('src.core.Sound').play(game.data,'Level_Up')
  end}}
end
function M.textBox(game,text,onDone,opts)
  local native=require('src.ui.Gen3NativeParty').message(game,text,onDone,opts)
  if native then return native end
  local TextBox=require('src.render.TextBox')
  local party
  if M.active()then
    local Party=require('src.ui.Gen3PartyMenu')
    for i=#game.stack.states,1,-1 do
      local state=game.stack.states[i]
      -- Medicine also retains the real party through HP fill and result
      -- acknowledgment. Its message must replace that party's prompt, using
      -- the same native window/font as teaching and mail feedback.
      if getmetatable(state)==Party and state.keepOpen
         and state.rsNative and not state.battle then party=state;break end
    end
  end
  if not party then return TextBox.new(game,text,onDone,opts)end
  local options={};for k,v in pairs(opts or{})do options[k]=v end
  options.box={tx=4,ty=15,tw=22,th=4};options.maxPixels=176
  options.uiWidth,options.uiHeight=240,160
  options.textX,options.line1Y,options.line2Y=32,120,136
  options.drawFrame,options.softWrap=false,false
  options.scrollDistance,options.scrollStep=16,2
  local box=TextBox.new(game,text,onDone,options)
  box.pages=party.rsNative:machinePages(box.pages)
  box.shown={};box:beginLine()
  box.rsMachineParty=party
  box.draw=function(self)return party.rsNative:drawMachineMessage(self)end
  return box
end
return M
