-- Public scoring functions, loaded unchanged through each engine's SDK.
local scoring = { calls = {}, mode = "prefer-second" }
mod.exports.scoring = scoring
local function number(value)
  if value ~= value then
    return "nan"
  end
  if value == math.huge then
    return "inf"
  end
  if value == -math.huge then
    return "-inf"
  end
  return value
end
local function layer(name)
  return function(view, move, score)
    scoring.lastView = view
    view.portableCount = (view.portableCount or 0) + 1
    move.portableCount = (move.portableCount or 0) + 1
    scoring.calls[#scoring.calls + 1] = {
      layer = name,
      move = move.id,
      before = number(score),
      viewCount = view.portableCount,
      moveCount = move.portableCount,
      hasMoves = view.moves ~= nil,
      target = view.target.mon.nickname,
      power = move.power,
      type = move.type,
      gen3Type = move.gen3Type,
    }
    if scoring.mode == "error" then
      error("intentional scoring failure")
    end
    if scoring.mode == "invalid" then
      return "invalid-score"
    end
    if scoring.mode == "nil" then
      return nil
    end
    if scoring.mode == "false" then
      return false
    end
    if scoring.mode == "zero" then
      return 0
    end
    if scoring.mode == "negative" then
      return -2
    end
    if scoring.mode == "infinity" then
      return math.huge
    end
    if scoring.mode == "nan" then
      return 0 / 0
    end
    if scoring.mode == "rng" then
      return score + view.rng(3, 7)
    end
    if name == "A" then
      return score + (move.id == "SOLARBEAM" and 40 or 5)
    end
    if name == "B" then
      return score * 2
    end
    return score + 3
  end
end
mod.content.ai_classes:register("PORTABLE_SCORE_A", { kind = "layer", score = layer("A") })
mod.content.ai_classes:register("PORTABLE_SCORE_B", { score = layer("B") })
mod.content.ai_classes:register("PORTABLE_SCORE_C", { kind = "layer", score = layer("C") })
mod.content.ai_classes:register("PORTABLE_CLASS_WITH_SCORE", { kind = "class", score = layer("wrong-class") })
mod.content.ai_classes:register("PORTABLE_BRAIN_WITH_SCORE", {
  kind = "brain",
  score = layer("wrong-brain"),
  brain = choose,
})
mod.content.ai_classes:register("LAYER_91", { kind = "layer", score = layer("wrong-numeric") })
