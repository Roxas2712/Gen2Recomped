package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
require("src.core.GameVersion").set("emerald")
local run = T.sdk.loadMods({ "mods/intro_probe" }, { fs = T.sdk.memfs({
  ["mods/intro_probe/manifest.json"] = '{"id":"intro_probe","name":"Intro probe","version":"1.0.0","api":2,"entry":"main.lua","games":["gen3"]}',
  ["mods/intro_probe/main.lua"] = [[
    local mod = ...
    mod.exports.started, mod.exports.finished = {}, {}
    mod.events:on("intro.birch_speech.started", function(ev)
      table.insert(mod.exports.started, ev)
    end)
    mod.events:on("intro.birch_speech.finished", function(ev)
      table.insert(mod.exports.finished, ev)
    end)
  ]],
}) })
T.eq(#run.errors, 0, "intro observer loads through public API")
local stack = { states = {} }
function stack:push(s) self.states[#self.states + 1] = s end
function stack:pop() return table.remove(self.states) end
local game = { data = run.data, save = { player = {} }, stack = stack }
local done = false
local exports = run.loader.exports.intro_probe
local speech = require("src.ui.BirchSpeech").new(game, function()
  T.eq(#exports.finished, 1, "finish event precedes completion callback")
  done = true
end)
stack:push(speech)
speech:enter()
T.eq(#exports.started, 1, "native intro enter emits start once")
T.eq(exports.started[1].speech, speech, "start identifies the actual speech")
T.eq(#exports.finished, 0, "enter does not finish the intro")
-- Exercise the native finish boundary independently of keyboard/name entry.
speech.answers = { gender = "girl", name = "MAY" }
stack:pop() -- the skipped question is closed before the native finish boundary
speech:finish()
T.eq(#exports.finished, 1, "native finish emits completion once")
T.eq(exports.finished[1].speech, speech, "finish identifies the same speech")
T.same(exports.finished[1].answers, speech.answers, "finish exposes the intro answers")
T.eq(done, true, "completion callback still runs")
T.eq(#stack.states, 0, "native finish removes the intro from the stack")
run.release()
T.finish("Public Birch intro events")
