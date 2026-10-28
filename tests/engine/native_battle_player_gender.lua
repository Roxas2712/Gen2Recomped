-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 for _,gender in ipairs{0,1}do
  local f=require('tools.battle-source-runtime.fixture').new(edition)
  package.loaded['src.core.Game']=f.game;f.game.save.player.gender=gender
  local b=f.fresh('TACKLE').battle;f.game.stack:push(b)
  local st=assert(Battle.getState())
  T.eq(st.playerGender,gender,'native '..edition..' battle exposes the actual player avatar')
  T.raises(function()st.playerGender=1-gender end,'not directly writable','presentation cannot replace player identity')
  T.eq(f.game.save.player.gender,gender,'read/write refusal preserves the native save')
  local seen=require('src.compat.gen1.TableIteration').snapshot(st)
  T.eq(seen.playerGender,gender,'declared source iteration includes player identity')
  f.game.stack:pop();Battle._service.release()
  T.eq(st.playerGender,gender,'retired battle retains a detached identity observation')
  f.game.save.player.gender=1-gender
  T.eq(st.playerGender,gender,'completed battle does not read a later avatar')
  f.close();G.release()
 end
end
T.finish('five-edition native battle player identity, read-only fields and retired observations')
