-- The public scorer runs in real native opponent producers, with physical slots.
return function(f, backend)
  local T, rows, native = f.T, {}, backend == "gen1"
  local ai, registry, oldPack
  if native then
    ai = require("src.core.game3.battle.ai")
    registry = require("src.core.game3.battle.mod_registries")
    oldPack = ai._pack
    registry.bind(f.data)
  else
    f.game.mods = f.result.loader
  end
  local scoring, brain = f.e.scoring, f.e.brain
  for _, spec in ipairs({
    { name = "class-only", class = "PORTABLE_SCORE_A", count = 2, slot = 2 },
    { name = "mods-only", mods = { "PORTABLE_SCORE_A", "PORTABLE_SCORE_B" }, count = 4, slot = 2 },
    {
      name = "class-last",
      class = "PORTABLE_SCORE_C",
      mods = { "PORTABLE_SCORE_A", "PORTABLE_SCORE_B" },
      count = 6,
      slot = 2,
    },
    { name = "duplicate-layers", mods = { "PORTABLE_SCORE_A", "PORTABLE_SCORE_A" }, count = 4, slot = 2 },
    { name = "literal-numeric-id", mods = { 91, "PORTABLE_SCORE_A" }, count = 2, slot = 2 },
    { name = "unknown-id", mods = { "NO_SUCH_LAYER", "PORTABLE_SCORE_A" }, count = 2, slot = 2 },
    {
      name = "class-score-ignored",
      mods = { "PORTABLE_CLASS_WITH_SCORE", "PORTABLE_SCORE_A" },
      count = 2,
      slot = 2,
    },
    {
      name = "brain-score-ignored",
      mods = { "PORTABLE_BRAIN_WITH_SCORE", "PORTABLE_SCORE_A" },
      count = 2,
      slot = 2,
    },
    { name = "nil-preserves", mode = "nil", count = 2, slot = 1 },
    { name = "false-preserves", mode = "false", count = 2, slot = 1 },
    { name = "zero-is-score", mode = "zero", count = 2, slot = 1 },
    { name = "negative-score", mode = "negative", count = 2, slot = 1 },
    { name = "infinite-score", mode = "infinity", count = 2, slot = 1 },
    { name = "nan-score", mode = "nan", count = 2, slot = 1 },
    { name = "invalid-score-contained", mode = "invalid", count = 2, slot = 1 },
    { name = "callback-error-contained", mode = "error", count = 1, slot = 1 },
    { name = "callback-rng", mode = "rng", count = 2, slot = 1 },
    { name = "zero-pp", zeroPP = 2, count = 1, slot = 1 },
    { name = "disabled", disabled = 2, count = 1, slot = 1 },
    { name = "first-slot-disabled", disabled = 1, count = 1, slot = 2 },
    { name = "sparse-middle-slot", sparse = true, count = 2, slot = 3 },
    { name = "duplicate-move-slots", duplicate = true, count = 2, slot = 1 },
    { name = "all-zero-pp", allZero = true, count = 0, struggle = true },
    {
      name = "valid-brain-skips-layers",
      class = "PORTABLE_BRAIN_WITH_SCORE",
      brainPick = 2,
      count = 0,
      slot = 2,
    },
    {
      name = "invalid-brain-uses-layers",
      class = "PORTABLE_BRAIN_WITH_SCORE",
      brainPick = 8,
      count = 2,
      slot = 2,
    },
    {
      name = "brain-error-contained",
      class = "PORTABLE_BRAIN_WITH_SCORE",
      brainError = true,
      count = 0,
      slot = 1,
    },
    { name = "right-double", double = true, id = 3, count = 2, slot = 2 },
    { name = "right-double-target-two", double = true, id = 3, targetDraw = 2, count = 2, slot = 2 },
    { name = "flags-without-pack", flags = 1, count = 2, slot = 2 },
    { name = "native-program-then-layer", flags = 1, program = true, count = 2, slot = 2 },
    { name = "two-native-programs", flags = 3, program = true, count = 2, slot = 2 },
    {
      name = "program-double-left",
      flags = 1,
      program = true,
      double = true,
      count = require("src.core.GameVersion").get() == "emerald" and 0 or 2,
      slot = require("src.core.GameVersion").get() == "emerald" and 1 or 2,
    },
    {
      name = "program-double-right",
      flags = 1,
      program = true,
      double = true,
      id = 3,
      count = require("src.core.GameVersion").get() == "emerald" and 0 or 2,
      slot = require("src.core.GameVersion").get() == "emerald" and 1 or 2,
    },
    {
      name = "program-double-lower",
      flags = 2,
      program = true,
      double = true,
      count = require("src.core.GameVersion").get() == "emerald" and 0 or 2,
      slot = require("src.core.GameVersion").get() == "emerald" and 1 or 2,
    },
    {
      name = "program-double-auto-flag",
      program = true,
      double = true,
      count = require("src.core.GameVersion").get() == "emerald" and 0 or 2,
      slot = require("src.core.GameVersion").get() == "emerald" and 1 or 2,
    },
    { name = "program-disabled-first", flags = 1, program = true, disabled = 1, count = 1, slot = 2 },
    { name = "program-zero-pp-first", flags = 1, program = true, zeroPP = 1, count = 1, slot = 2 },
    { name = "program-sparse-slots", flags = 1, program = true, sparse = true, count = 2, slot = 3 },
  }) do
    local b = f.freshDecision({}, spec.double)
    local id = spec.id or 1
    local who = native and require("src.core.game3.battle.state").battler(b, id) or b:battlerAt(id)
    local mods = spec.mods or { "PORTABLE_SCORE_A" }
    if spec.name == "class-only" then
      mods = {}
    end
    local oldProgram = f.data.constants.gen3BattleAI
    if native then
      b.aiClass, b.aiMods, b.aiFlags = spec.class, mods, spec.flags or 0
      who.mon.moves, who.mon.pp = { 33, 76 }, { 10, 10 }
      if spec.sparse then
        who.mon.moves, who.mon.pp = { 33, 0, 76 }, { 10, 0, 10 }
      end
      if spec.duplicate then
        who.mon.moves = { 33, 33 }
      end
      if spec.zeroPP then
        who.mon.pp[spec.zeroPP] = 0
      end
      if spec.allZero then
        who.mon.pp = { 0, 0 }
      end
      if spec.disabled then
        who.expDisabledMove = spec.disabled == 1 and 33 or 76
      end
      ai._pack = spec.program
          and {
            table = { "main", "low" },
            scripts = {
              main = { { op = "if_move", move = 33, target = "boost" }, { op = "end" } },
              boost = { { op = "score", delta = 20 }, { op = "end" } },
              low = { { op = "score", delta = -5 }, { op = "end" } },
            },
          }
        or nil
    else
      b.trainer.aiClass, b.enemyAIMods, b.trainer.aiFlags = spec.class, mods, spec.flags or 0
      who.curMoves = { { id = f.ids.TACKLE, pp = 10 }, { id = f.ids.SOLARBEAM, pp = 10 } }
      if spec.sparse then
        who.curMoves = { who.curMoves[1], { id = 0, pp = 0 }, who.curMoves[2] }
      end
      if spec.duplicate then
        who.curMoves[2].id = f.ids.TACKLE
      end
      who.mon.moves = who.curMoves
      if spec.zeroPP then
        who.curMoves[spec.zeroPP].pp = 0
      end
      if spec.allZero then
        who.curMoves[1].pp, who.curMoves[2].pp = 0, 0
      end
      if spec.disabled then
        who.disabledSlot = spec.disabled
      end
      f.data.constants.gen3BattleAI = spec.program
          and {
            entries = { [0] = 1, [1] = 5 },
            code = {
              { name = "if_move", args = { 33, 3 }, next = 2 },
              { name = "end", args = {} },
              { name = "score", args = { 20 }, next = 4 },
              { name = "end", args = {} },
              { name = "score", args = { 251 }, next = 6 },
              { name = "end", args = {} },
            },
          }
        or nil
    end
    local draws = {}
    b.rng = function(lo, hi)
      draws[#draws + 1] = { lo, hi }
      return hi == 65535 and (spec.targetDraw or 0) or lo or 0
    end
    scoring.calls, scoring.lastView, scoring.mode = {}, nil, spec.mode or "prefer-second"
    brain.calls, brain.seen, brain.mode, brain.pick =
      0, {}, spec.brainError and "error" or "pick", spec.brainPick
    f.e.state.mode = "suppress"
    local ok, action = pcall(function()
      if native then
        return require("src.core.game3.battle.commands").enemyAction(b, id)
      end
      return b:enemyAction(who)
    end)
    T.eq(ok, true, spec.name .. " controller contains failures")
    local slot, struggle
    if native then
      slot, struggle = action and action.slot, action and action.move == "STRUGGLE"
    else
      for i, move in ipairs(who.curMoves) do
        if action == move then
          slot = i
        end
      end
      struggle = action and action.struggle == true
    end
    T.eq(#scoring.calls, spec.count, spec.name .. " scorer invocation count")
    if spec.slot then
      T.eq(slot, spec.slot, spec.name .. " selected physical slot")
    end
    if spec.struggle then
      T.eq(struggle, true, "all unusable skips scorers")
    end
    if scoring.lastView then
      T.eq(scoring.lastView.battle, b, spec.name .. " exact native battle")
      T.eq(scoring.lastView.user, who, spec.name .. " exact native user")
      T.eq(scoring.lastView.data, f.data, spec.name .. " current mod data")
      T.eq(scoring.lastView.rng, b.rng, spec.name .. " native RNG")
      local tid = spec.double and (spec.targetDraw or 0) or 0
      T.eq(
        scoring.lastView.target,
        native and require("src.core.game3.battle.state").battler(b, tid) or b:battlerAt(tid),
        spec.name .. " chosen native target"
      )
    end
    local def = native and require("src.core.game3.battle.moves")._rom[33] or f.data.moves[f.ids.TACKLE]
    T.eq(def.portableCount, nil, spec.name .. " move view cannot mutate shared definition")
    rows[#rows + 1] = {
      scoring = spec.name,
      slot = slot or false,
      struggle = struggle or false,
      calls = scoring.calls,
      brainCalls = brain.calls,
      rng = draws,
    }
    f.data.constants.gen3BattleAI = oldProgram
  end
  if native then
    ai._pack = oldPack
    registry.bind(nil)
  end
  return rows
end
