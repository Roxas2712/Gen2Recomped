-- Profiling adapters for owned benchmark copies; arguments and returns stay live.
local FP=require("src.core.FrameProfile")
local M={}
local setup
local function pack(...)return {n=select("#",...),...}end
function M.startSetup()
  assert(not setup,"setup profiling already active")
  setup={}
end
function M.stopSetup()
  local result=assert(setup,"setup profiling is not active")
  setup=nil
  return result
end
function M.call(label,fn,...)
  local bucket=setup
  if not bucket and not FP.enabled() then return fn(...) end
  local start=bucket and FP.now()
  local first=(...)
  local close=FP.section(label)
  local values=pack(fn(...))
  close()
  if bucket then
    local map=type(first)=="table" and first.id or "<global>"
    map=tostring(map or "<global>")
    bucket[label]=bucket[label] or {}
    local row=bucket[label][map] or {calls=0,totalMs=0,maxMs=0}
    local elapsed=(FP.now()-start)*1000
    row.calls,row.totalMs,row.maxMs=row.calls+1,row.totalMs+elapsed,math.max(row.maxMs,elapsed)
    bucket[label][map]=row
  end
  return unpack(values,1,values.n)
end
function M.wrapSetup(label,fn)
  return function(...)
    if not setup then return fn(...) end
    return M.call(label,fn,...)
  end
end
return M
