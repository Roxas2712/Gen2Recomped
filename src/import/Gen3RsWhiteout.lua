-- The native RS whiteout script repairs story state before the heal warp,
-- including Mr. Briney's ferry location. A heal warp alone can strand a
-- player on Dewford after losing a mainland battle.
local M={}
local OPS={call=true,['goto']=true,compare_var_to_value=true,goto_if=true,checkflag=true,
  clearflag=true,setflag=true,setvar=true,['return']=true,['end']=true}
function M.read(x)
  assert(x.version=='ruby'or x.version=='sapphire')
  local S=require('compat.gen1-rs.Loader').new(x.version)('src.import.gba.syms').of(x.version)
  local root=S.off('EventScript_WhiteOut');local queue={root};local seen={};local scripts={};local labels={}
  while #queue>0 do
    local at=table.remove(queue)
    if not seen[at]then
      seen[at]=true;assert(#labels<128,'Native RS whiteout graph is unexpectedly large')
      local lines,why=x:decodeScriptAt(at,queue);assert(not why,why)
      local label=('S%07X'):format(at);labels[#labels+1]=label;local rows={}
      for i,line in ipairs(lines)do
        assert(OPS[line.name],'RS whiteout recovery must remain an immediate state-reset script')
        local row={line.name};for k,value in ipairs(line.args)do row[k+1]=value end;rows[i]=row
      end
      scripts[label]=rows
    end
  end
  table.sort(labels)
  local entry=('S%07X'):format(root)
  assert(scripts[entry]and #scripts[entry]>0,'Empty native RS whiteout script')
  return {format=1,version=x.version,entry=entry,labels=labels,
    brineyDewfordScript=S.off('DewfordTown_EventScript_Briney'),
    source='ROM: EventScript_WhiteOut and its native branch/call graph'},scripts
end
function M.extract(x)
  x:beginStage('Ruby/Sapphire whiteout recovery scripts')
  local spec,scripts=M.read(x);local pool=assert(x._scriptPool)
  for label,rows in pairs(scripts)do pool.scripts[label]=rows end
  local count,commands=0,0
  for _,rows in pairs(pool.scripts)do count=count+1;commands=commands+#rows end
  if pool.info then pool.info.scriptCount=count;pool.info.commandCount=commands end
  x._constants.gen3RsWhiteout=spec;x:write('map_scripts',pool)
end
function M.valid(spec,version,pool)
  if type(spec)~='table'or spec.format~=1 or spec.version~=version
    or (version~='ruby'and version~='sapphire')or type(spec.entry)~='string'
    or type(spec.labels)~='table'or #spec.labels==0 or type(pool)~='table'
    or type(pool.scripts)~='table'then return false end
  for _,label in ipairs(spec.labels)do if type(pool.scripts[label])~='table'then return false end end
  return type(pool.scripts[spec.entry])=='table'
end
function M.apply(game,world)
  local version=require('src.core.GameVersion').get()
  local data=game.data;local spec=data.constants and data.constants.gen3RsWhiteout
  if not M.valid(spec,version,data.map_scripts)then return false end
  local script=assert(require('src.script.Gen3ScriptVM').compile(data,spec.entry),
    'Native RS whiteout script could not compile')
  -- The native reset graph contains no movement, UI or yielding special.
  -- A separate immediate runner preserves the defeated trainer's own stack;
  -- that caller must end on its ordinary loss path after the battle returns.
  local runner=require('src.script.ScriptRunner').new(game,world)
  local completed=false
  runner:run(script,{rsWhiteoutRecovery=true,source={strict=true,hook='native-rs-whiteout'},
    onDone=function()completed=true end})
  assert(completed and not runner:isRunning(),'Native RS whiteout state reset failed or unexpectedly yielded')
  return true
end
return M
