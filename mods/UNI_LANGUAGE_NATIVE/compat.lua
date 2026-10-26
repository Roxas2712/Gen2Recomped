-- Stock Gen3 ends the insufficient-party double-battle message with a halted
-- native poll, but omits the original trainer_battle.inc releaseall. Restore
-- that release only for this completed rejection path, through a mod-owned
-- script hook; ordinary battles and running messages are untouched.
return function(mod)
 local Party=require('src.core.game3.party')
 local Ops=require('src.core.game3.scripting.ops_a')
 mod.hooks:wrap('script.command',function(next,context,name,row)
  local vm=context and context.runner
  local mode=type(row)=='table' and tonumber(row.type)
  local double=mode==4 or mode==6 or mode==7 or mode==8
  local session=context and (context.session or context.save)
  local watch=name=='trainerbattle' and double and vm and vm.ctx and session
    and Party.monsStateToDoubles(session.party)~=Party.PLAYER_HAS_TWO_USABLE_MONS
  local previous=watch and vm.ctx.nativePoll
  local result=next(context,name,row)
  -- The stock adapter uses FRLG's 29-entry limit for every game. Emerald
  -- also has index 29 (Battle Pyramid). Resolve only that numeric fallback
  -- through the active ROM registry; retain the original command and IDs.
  if name=='bufferstdstring' and vm and vm.ctx and type(row)=='table'
    and require('src.core.GameVersion').get()=='emerald' then
   local src=tonumber(row.src or row[2])
   if src and src>=0x4000 then
    src=require('src.core.game3.scripting.flags').getVar(vm.store,vm.ctx,src)
   end
   local dest=(tonumber(row.dest or row[1]) or 0)+1
   if src==29 and vm.ctx.stringVars and vm.ctx.stringVars[dest]=='29' then
    vm.ctx.stringVars[dest]=require('src.core.game3.rom_text').plain('stdstring:29')
   end
  end
  if not watch or not result then return result end
  local ctx=vm.ctx
  local function release()
   if ctx.status=='halted' and ctx.frozen then
    Ops.dispatchUnhooked(vm,{op='releaseall'})
    ctx.mode='bytecode';ctx.nativePoll=nil
   end
  end
  if ctx.status=='halted' then release()
  elseif ctx.mode=='native' and type(ctx.nativePoll)=='function' and ctx.nativePoll~=previous then
   local poll=ctx.nativePoll
   ctx.nativePoll=function(...)
    local ready=poll(...)
    release()
    return ready
   end
  end
  return result
 end)
end
