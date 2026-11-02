-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Test-only oracle. Interpret imported cartridge reset commands on a detached
-- snapshot; never call the production repair helper or mutate the live game.
local M={}
function M.expected(save,data,edition)
  local map=save.player and save.player.map
  if edition~='emerald'or(map~='MAP_G00_N08'and map~='MAP_G16_N10')
    or(tonumber((save.gen3Vars or{})[0x409C])or 0)==0 then return save,false end
  local S=require('src.core.SaveSerializer')
  local expected=assert(S.decode(S.encode(save)))
  local spec=assert(data.constants.gen3RsWhiteout)
  assert(spec.format==1 and spec.version=='emerald')
  local scripts=assert(data.map_scripts.scripts)
  local function label(at)
    if type(at)=='string'then return at end
    assert(type(at)=='number');if at>=0x08000000 then at=at-0x08000000 end
    return('S%07X'):format(at)
  end
  local function flag(id)return('FLAG_G3_%04X'):format(id)end
  local current,index,comparison,stack=spec.entry,1,0,{}
  expected.flags=expected.flags or{};expected.gen3Vars=expected.gen3Vars or{}
  for _=1,256 do
    local row=assert(assert(scripts[current],'Missing native reset label')[index],'Unterminated native reset graph')
    index=index+1;local op=row[1]
    if op=='call'then stack[#stack+1]={current,index};current,index=label(row[2]),1
    elseif op=='return'then local back=assert(table.remove(stack));current,index=back[1],back[2]
    elseif op=='goto'then current,index=label(row[2]),1
    elseif op=='end'then return expected,true
    elseif op=='setflag'then expected.flags[flag(row[2])]=true
    elseif op=='clearflag'then expected.flags[flag(row[2])]=false
    elseif op=='setvar'then expected.gen3Vars[row[2]]=row[3]
    elseif op=='checkflag'then comparison=expected.flags[flag(row[2])]and 1 or 0
    elseif op=='compare_var_to_value'then
      local a,b=expected.gen3Vars[row[2]]or 0,row[3];comparison=a<b and 0 or(a==b and 1 or 2)
    elseif op=='goto_if'then
      local c=row[2];local take=(c==0 and comparison==0)or(c==1 and comparison==1)or(c==2 and comparison==2)
        or(c==3 and comparison<=1)or(c==4 and comparison>=1)or(c==5 and comparison~=1)
      assert(c>=0 and c<=5);if take then current,index=label(row[3]),1 end
    else error('Unexpected native recovery command '..tostring(op))end
  end
  error('Native recovery oracle exceeded its bounded command count')
end
return M
