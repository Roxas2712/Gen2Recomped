-- Additional, explicitly selected contracts. Contributions by Roxas2712.
local M={REVISION=1,REFERENCE='2aec7650cb01845a4e98f1dbcf8a5c652990d984'}
local owners=setmetatable({},{__mode='k'})
function M.retire(loader,modId)
  local list=owners[loader];if not list then return end
  if modId then local feature=list[modId];if feature then feature.release();list[modId]=nil end
  else for _,feature in pairs(list)do feature.release()end;owners[loader]=nil end
end
function M.unloadAll()for loader in pairs(owners)do M.retire(loader)end end
function M.forHost(getGame,data,loader,modId)
  local released,world=false,nil
  local trades=setmetatable({},{__mode='k'})
  local feature={revision=M.REVISION,reference=M.REFERENCE}
  local battle=require('src.features.Gen1BattleSimulation')
  feature.battle={sync=require('src.features.Gen1SyncBattle').new,new=function(options)return battle.new(options)end,bundle=function(options)return battle.bundle(options)end,revision=battle.REVISION}
  local save=require('src.features.Gen1Save5')
  feature.save5={
    import=function(bytes)return save.import(bytes,data)end,
    export=function(record)return save.export(record,data)end,
  }
  function feature.release()
    released=true
    if world then world:release();world=nil end
    for trade in pairs(trades)do trade:close()end
  end
  if loader and modId then
    owners[loader]=owners[loader]or setmetatable({},{__mode='v'})
    owners[loader][modId]=feature
  end
  local function game()
    if released then return nil,'feature owner retired'end
    local owner=getGame();if not owner then return nil,'no active native game'end
    if owner.data~=data then return nil,'feature dataset retired'end
    return owner
  end
  function feature.world()
    local owner,why=game();if not owner then return nil,why end
    if world and world:valid()then return world end
    world,why=require('src.features.Gen1WorldSession').new(owner,function()return game()==owner end)
    return world,why
  end
  feature.link3={
    openCable=function(options)
      local owner,why=game();if not owner then return nil,why end
      local opts={};for k,v in pairs(options or{})do opts[k]=v end
      opts.checkOwner=function()return game()==owner end
      local screen,reason=require('src.features.Gen1CableLobby').open(owner,opts)
      if screen then trades[screen]=true end
      return screen,reason
    end,
    gbaExchange=require('src.features.Gen1GbaExchange').new,
    hello=function()
      local owner,why=game();if not owner then return nil,why end
      return require('src.features.Gen1Link3').hello(owner)
    end,
    newTrade=function(peer)
      local owner,why=game();if not owner then return nil,why end
      local trade,reason=require('src.features.Gen1Link3').newTrade(owner,peer,{checkOwner=function()return game()==owner end})
      if trade then trades[trade]=true end
      return trade,reason
    end,
    codec=function()
      local owner,why=game();if not owner then return nil,why end
      return require('src.features.Gen1Link3').codec(data,require('src.core.GameVersion').generation(),owner.mods)
    end,
  }
  return feature
end
return M
