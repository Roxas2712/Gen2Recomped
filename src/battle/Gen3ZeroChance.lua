-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Ruby/Sapphire's effect-chance opcode still rolls when the selected native
-- script carries effect byte zero. This is not a probability of applying a
-- status. Nonzero/dynamic payload descriptors retain their separate owners.
-- Opcode sites: pokeruby battle_script_commands.c:2978 and native hit scripts.
local C = {}
local sites = {}
for _, id in ipairs({0,12,14,15,17,21,22,38,39,40,41,43,45,55,56,61,63,64,74,78,81,
  87,88,89,96,99,101,103,110,117,119,121,122,123,128,130,131,135,141,144,145,
  149,151,161,163,169,170,185,189,190,196,203,207,29,44,104,186}) do sites[id]=true end
function C.finish(ctx, reason)
  local V = require('src.core.GameVersion')
  if not V.isGen3() or not (V.get()=='ruby' or V.get()=='sapphire') or ctx.gbaZeroChanceDone then return end
  local id = tonumber(ctx.move.gen3Effect)
  local selected = sites[id] or id==155 and tonumber(ctx.move.index or ctx.move.numId)~=340
  if not selected or reason=='absorbed' then return end
  if reason=='immune' then
    if id==117 or id==119 then return end
  elseif reason=='fainted' then
    if id~=29 and id~=44 and id~=104 then return end
  elseif reason and id~=104 then return end
  ctx.gbaZeroChanceDone = true
  local rng = ctx.battle.rng or ctx.rng
  rng(0,99)
end
return C
