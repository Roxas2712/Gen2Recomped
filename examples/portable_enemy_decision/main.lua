local mod = ...
mod.exports.api = mod
local out = { mode = "delegate", calls = 0, contexts = {} }
mod.exports.state = out
mod.exports.available = mod:supports("hooks", "battle.enemy_switch_or_item")
if not mod.exports.available then
  return
end
out.stop = mod.hooks:wrap("battle.enemy_switch_or_item", function(next, battle)
  out.calls = out.calls + 1
  out.contexts[#out.contexts + 1] = battle
  if out.mode == "fail-before" then
    error("intentional enemy-decision failure before next")
  end
  if out.mode == "suppress" then
    return false
  end
  if out.mode == "nil" then
    return nil
  end
  if out.mode == "override" then
    return out.decision
  end
  if out.mode == "true" then
    return true
  end
  local value = next(battle)
  out.last = value
  if out.mode == "next-false" then
    return false
  end
  if out.mode == "next-item" then
    return { kind = "item", item = "POTION" }
  end
  if out.mode == "mutate" and type(value) == "table" then
    value.item = 19
  end
  if out.mode == "repeat" then
    out.repeated = next(battle)
  end
  if out.mode == "fail-after" then
    error("intentional enemy-decision failure after next")
  end
  if out.mode == "claim" then
    return true
  end
  return value
end)
