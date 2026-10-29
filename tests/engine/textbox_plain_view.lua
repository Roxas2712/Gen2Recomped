-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
local TextBox = require('src.render.TextBox')

-- A stat-effect consumer must be able to compare native failure prose even
-- when the cartridge printer divides it into lines/pages and adds an end token.
local function failed(message)
  local plain = TextBox.strip(message)
  return plain == 'But, it failed!' or plain == 'Nothing happened!'
end
for _,message in ipairs{
  'But, it failed!', 'But, it\nfailed!\f',
  '\tBut, it\vfailed!{DONE}', 'But, it failed!{PROMPT}',
  'Nothing\nhappened!{DONE}', 'Nothing\v\fhappened!{PROMPT}',
}do T.eq(failed(message),true,'printer controls do not change failure classification')end
for _,message in ipairs{'DEFENSE fell!','Nothing happened to the item.','But, it failed! Extra prose.'}do
  T.eq(failed(message),false,'visible message content retains authority')
end
T.eq(TextBox.strip(nil),'')
T.eq(TextBox.strip(' \n\v\f\t '),'')
T.eq(TextBox.strip(42),'42')
T.eq(TextBox.strip('POKéMON ♀\nwon!{DONE}'),'POKéMON ♀ won!','Unicode remains intact')
T.eq(TextBox.strip('{PLAYER}\nused <PK><MN>!'),'{PLAYER} used <PK><MN>!',
  'plain viewing does not guess unresolved names or erase visible glyph tokens')
T.eq(select('#',TextBox.strip('Nothing happened!{DONE}')),1,'the public helper returns one value')
T.finish('plain textbox view and legacy message-consumer compatibility')
