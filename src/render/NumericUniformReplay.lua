-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Pending entries are names only. The bounded source bank remains the sole
-- snapshot owner; textures and opaque values always keep eager propagation.
local N={}
local unpack=table.unpack or unpack
local function numeric(value,depth)
 local kind=type(value)
 if kind=='number'or kind=='boolean'then return true end
 if kind~='table'or depth>=4 or getmetatable(value)~=nil then return false end
 local count,size=0,0
 for key,item in next,value do
  if type(key)~='number'or key<1 or key%1~=0 or key>256 or not numeric(item,depth+1)then return false end
  count=count+1;size=math.max(size,key)
 end
 return count==size
end
function N.numericBank(bank)
 for _,row in ipairs(bank)do
  if row.numeric==false then return false end
  if row.numeric~=true then
  for i=1,row.n do
   local v=row[i]
   if not(i==1 and type(v)=='string'and(v=='row'or v=='column'))and not numeric(v,0)then return false end
  end
  end
 end
 return true
end
function N.queue(variant,name)
 local pending=variant.numericPending
 if not pending then pending={};variant.numericPending=pending end
 if not pending[name]then variant.numericPendingCount=(variant.numericPendingCount or 0)+1 end
 pending[name]=true
end
function N.clear(variant,name)
 if variant.numericPending and variant.numericPending[name]then variant.numericPending[name]=nil;variant.numericPendingCount=variant.numericPendingCount-1 end
end
function N.apply(record,variant,stats)
 local pending=variant.numericPending;if not pending then return end
 for name in pairs(pending)do
  local bank=assert(record.bank[name],'missing deferred numeric bank')
  assert(N.numericBank(bank),'opaque value reached deferred numeric replay')
  if record.hook.hasUniform(variant.shader,name)then
   for _,row in ipairs(bank)do
    -- These rows contain detached primitive snapshots, with no resources to
    -- restore. Preserve every retained array prefix and matrix-layout tag.
    record.hook[row.method](variant.shader,name,unpack(row,1,row.n))
    stats.numericReplayWrites=stats.numericReplayWrites+1
    if stats.variantUniformWrites then stats.variantUniformWrites=stats.variantUniformWrites+1 end
   end
  end
  N.clear(variant,name)
 end
end
return N
