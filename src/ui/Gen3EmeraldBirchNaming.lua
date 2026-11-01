-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Embed the existing Emerald keyboard without popping its authoritative intro.
local M={}
function M.new(game)
  local api={}
  local current,proxy,completed
  function api.open(opts)
    assert(not current,'Emerald intro naming already active')
    local owner=game.stack:top()
    local player={};for key,value in pairs(game.save.player)do player[key]=value end
    player.gender=opts.gender==1 and 'girl'or 'boy'
    local save=setmetatable({player=player},{__index=game.save})
    local stack={}
    function stack:top()return self.screen end
    function stack:push(screen)self.screen=screen;if screen.enter then screen:enter()end end
    function stack:pop()
      local screen=self.screen;self.screen=nil
      if screen and screen.exit then screen:exit()end
      return screen
    end
    proxy=setmetatable({save=save,stack=stack},{__index=game})
    completed=false
    current=require('src.ui.NamingScreen').new(proxy,{kind='player',maxLen=7,
      default=opts.seed,onDone=function(name)
        assert(not completed,'Emerald intro name callback repeated')
        assert(game.stack:top()==owner,'Embedded keyboard popped the real intro')
        completed=true
        if opts.onDone then opts.onDone(name)end
      end})
    stack:push(current)
  end
  function api.handleInput(input)
    if not proxy then return end
    proxy.input={
      wasPressed=function(_,key)return input:wasPressed(key)end,
      pressed=function(_,key)return input:wasPressed(key)end,
      isDown=function(_,key)return input:isDown(key)end,
    }
  end
  function api.update(dt)if current and not completed then current:update(dt)end end
  function api.draw()if current then current:draw()end end
  function api.isOpen()return current~=nil end
  function api.dismiss()
    if proxy and proxy.stack:top()then proxy.stack:pop()end
    current,proxy,completed=nil,nil,nil
  end
  return api
end
return M
