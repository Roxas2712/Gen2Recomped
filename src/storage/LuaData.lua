-- Inventory and validate Lua records without discarding unsupported fields.
local L={MAX_NODES=200000,MAX_DEPTH=96}
local S=require('src.core.SaveSerializer')
function L.inspect(value)
  local report={schema=1,fields={},types={},nodes=0};local active={}
  local function visit(v,path,depth)
    report.nodes=report.nodes+1
    if report.nodes>L.MAX_NODES or depth>L.MAX_DEPTH then error('Lua data exceeds traversal limits at '..path,0) end
    local kind=type(v);report.types[kind]=(report.types[kind] or 0)+1
    if kind=='table' then
      if getmetatable(v) then error('A Lua metatable needs an explicit adapter at '..path,0) end
      if active[v] then error('A Lua reference cycle needs an explicit adapter at '..path,0) end
      active[v]=true
      for k,child in pairs(v) do
        if type(k)~='string' and type(k)~='number' or type(k)=='number' and (k~=k or k==math.huge or k==-math.huge) then error('Unsupported Lua key at '..path,0) end
        visit(child,path..'.'..tostring(k),depth+1)
      end
      active[v]=nil
    elseif kind~='string' and kind~='boolean' and kind~='number' and kind~='nil' then error('Unsupported Lua '..kind..' at '..path,0)
    elseif kind=='number' and (v~=v or v==math.huge or v==-math.huge) then error('Non-finite Lua number at '..path,0) end
  end
  local ok,why=pcall(visit,value,'$',0)
  if type(value)=='table' then for k,v in pairs(value) do report.fields[#report.fields+1]={name=tostring(k),kind=type(v)} end end
  table.sort(report.fields,function(a,b) return a.name<b.name end)
  report.serializable=ok;report.reason=not ok and tostring(why) or nil;return report
end
function L.encode(value,limit)
  local report=L.inspect(value);if not report.serializable then return nil,report.reason,report end
  local ok,bytes=pcall(S.encode,value)
  if not ok then return nil,tostring(bytes),report end
  if #bytes>(limit or 16*1024*1024) then return nil,'Lua record exceeds its byte limit.',report end
  return bytes,nil,report
end
return L
