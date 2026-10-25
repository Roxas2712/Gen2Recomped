-- Resolve the live owner without bootstrapping Game or keeping a retired world.
local Version = require('src.core.GameVersion')
local M = {}
function M.resolve(game)
  local facade = package.loaded['src.core.Game3']
  if type(facade) == 'table' and type(facade.native) == 'function' then
    game = facade.native(game)
  end
  game = game or package.loaded['src.core.Game']
  local info = Version.info(Version.get())
  if type(game) ~= 'table' or not info or info.generation ~= 3 then
    return nil, 'no native GBA session'
  end
  local states = game.stack and game.stack.states
  local world
  if type(states) == 'table' then
    for i = #states, 1, -1 do
      if states[i].isOverworld then world = states[i]; break end
    end
  else
    world = game.overworld
  end
  if not (world and world.isOverworld and world.player and world.map) then
    return nil, 'no active native player'
  end
  if not (game.data and game.data.maps and world.map.def
      and game.data.maps[world.map.id] == world.map.def) then
    return nil, 'native world belongs to a retired dataset'
  end
  return game, world, world.player
end
function M.acceptsInput(game, world, player)
  local owner, current, actor = M.resolve(game)
  if owner ~= game or current ~= world or actor ~= player then return false end
  local states = game.stack and game.stack.states
  if states and states[#states] ~= world then return false end
  return not world.battleActive and not (world.busy and world:busy())
end
return M
