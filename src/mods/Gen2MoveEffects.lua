-- Old Gen2 custom effects take positional model/mon arguments. Native
-- effects take one context. Adapt only the declared positional signature.
local M={}
function M.positional(fn)
  if type(fn)~='function' then return false end
  local info=debug and debug.getinfo and debug.getinfo(fn,'u')
  local count=info and info.nparams
  if count==nil then
    local ok,util=pcall(require,'jit.util')
    if ok then local row=util.funcinfo(fn);count=row and row.params end
  end
  return count and count>=4 or false
end
function M.adapt(record)
  if not M.positional(record.run) then return record end
  local out={};for key,value in pairs(record)do out[key]=value end
  local run=record.run
  out.run=function(ctx)
    local screen=ctx.battle
    run(screen.battle,ctx.user.mon,ctx.target.mon,ctx.move,ctx.move.id,false)
    -- Source effects enqueue their own messages through the native owner.
    return {}
  end
  return out
end
return M
