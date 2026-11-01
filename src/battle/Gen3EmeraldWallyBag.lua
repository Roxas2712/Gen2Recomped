-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original scripted Emerald bag; virtual tutorial rows never touch inventory.
local M={}
function M.open(wally)
 local battle=wally.battle;local game=battle.game
 local Pocket=require('src.ui.Gen3EmeraldBagPocket')
 local Sound=require('src.core.Sound')
 local function row(id)
  local def=assert(game.data.items[id]);return{id=id,label=def.name,description=def.description,qty=1}
 end
 local function rows(id)return{row(id),{close=true}}end
 local function selectSound()Sound.play(game.data,'Press_AB')end
 battle.phase='messages';battle.afterQueue='menu'
 battle:ui(function()
  local bag
  bag=require('src.ui.Gen3BagMenu').new(game,{pocket='ITEM',battle=battle,
   noInput=true,wallyTutorial=true,rows=rows('POTION'),script=function(menu)
    -- The cartridge delegates its task during the pocket animation, so
    -- those seventeen frames do not advance the next 102-frame delay.
    if Pocket.update(menu)then return end
    wally.bagTicks=wally.bagTicks+1
    if wally.bagTicks==102 then
     menu.scriptRows=rows('POKE_BALL');Pocket.start(menu,1)
     wally:record('bag-pocket-switch')
    elseif wally.bagTicks==204 then
     selectSound();wally:record('bag-use-menu');menu.script=nil
     local native=assert(game.data.constants.gen3ItemMenu)
     game.stack:push(require('src.ui.Gen3ItemMenu').new(game,{columns=1,emeraldBag=menu,noInput=true,
      entries={{kind='use',label=assert(native.labels[1])},
       {kind='cancel',label=assert(native.labels[native.cancel])}},
      script=function(popup)
       wally.bagTicks=wally.bagTicks+1
       if wally.bagTicks==306 then selectSound();popup:close('use')end
      end,
      onPick=function(kind)
       assert(kind=='use'and game.stack:top()==bag)
       wally:record('bag-use')
       -- Retain the native fade with input disabled throughout the demo.
       bag.emeraldFade={kind='close',age=0,done=function()
        assert(game.stack:top()==bag);game.stack:pop();battle:oldManThrow()
       end}
      end}))
    end
   end})
  assert(bag.emerald,'Original Emerald tutorial bag resources required')
  bag.emeraldFade={kind='open',age=0};wally.bagTicks=0;wally:record('bag-open')
  return bag
 end)
end
return M
