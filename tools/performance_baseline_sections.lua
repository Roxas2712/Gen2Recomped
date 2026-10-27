-- Profiling adapters for owned benchmark copies; arguments and returns stay live.
local FP=require("src.core.FrameProfile")
local M={}
local setup
local function pack(...)return {n=select("#",...),...}end
function M.startSetup()
  assert(not setup,"setup profiling already active")
  setup={labels={},active=0}
end
function M.stopSetup()
  local bucket=assert(setup,"setup profiling is not active")
  local result={labels={},inFlightAtStop=bucket.active}
  for label,maps in pairs(bucket.labels) do
    result.labels[label]={}
    for map,row in pairs(maps) do
      local copy={};for key,value in pairs(row) do copy[key]=value end
      result.labels[label][map]=copy
    end
  end
  setup=nil
  return result
end
function M.call(label,fn,...)
  local bucket=setup
  if not bucket and not FP.enabled() then return fn(...) end
  local start=bucket and FP.now()
  if bucket then bucket.active=bucket.active+1 end
  local first=(...)
  local close=FP.section(label)
  local values=pack(fn(...))
  close()
  if bucket then
    local map=type(first)=="table" and first.id or "<global>"
    map=tostring(map or "<global>")
    bucket.labels[label]=bucket.labels[label] or {}
    local row=bucket.labels[label][map] or {calls=0,totalMs=0,maxMs=0}
    local elapsed=(FP.now()-start)*1000
    row.calls,row.totalMs,row.maxMs=row.calls+1,row.totalMs+elapsed,math.max(row.maxMs,elapsed)
    if type(values[1])=="boolean" then
      local key=values[1] and "trueReturns" or "falseReturns"
      row[key]=(row[key] or 0)+1
    end
    bucket.labels[label][map]=row
    bucket.active=bucket.active-1
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
