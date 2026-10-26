package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.harness")
local V = require("src.core.GameVersion")
local Tokens = require("src.script.Tokens")
local game={data={tokens={KNOWN=function(_,arg)return arg or "ok"end,
  EMPTY=function()return nil end,BROKEN=function()error("fixture failure")end}}}
for _,edition in ipairs{"red","yellow","gold","crystal","firered","emerald","platinum","black"}do
  V.set(edition)
  local classic=V.isGen1()or V.isGen2()
  T.eq(Tokens.expand(game,"A{UNKNOWN}B"),classic and "AB"or"A{UNKNOWN}B",edition.." unknown-token fallback")
  T.eq(Tokens.expand(game,"A{BROKEN}B"),classic and "AB"or"A{BROKEN}B",edition.." handler-error fallback")
  T.eq(Tokens.expand(game,"A{EMPTY}B"),"AB",edition.." nil handler output still drops")
  T.eq(Tokens.expand(game,"A{KNOWN:value}B"),"AvalueB",edition.." registered arguments remain unchanged")
  T.eq(Tokens.expand(game,"A{NUM:value, 2 | FLAGS}B"),"A{NUM:value, 2 | FLAGS}B",edition.." outside-grammar spans stay literal")
end
T.eq(Tokens.expand(game,nil),nil,"missing text remains safe")
T.finish("classic_token_fallback")
