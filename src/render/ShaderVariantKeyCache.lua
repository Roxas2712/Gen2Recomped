-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Three states per fixed-kind branch: dynamic, false/zero, true/one. At most
-- 33 trits fit exactly in Lua's 53-bit integer range; larger plans fall back.
local K={}
local function code(literal)
 if literal==nil then return 0 end
 if literal=='false'or literal=='0.0'then return 1 end
 if literal=='true'or literal=='1.0'then return 2 end
end
function K.new(plan,values,limit)
 if #plan.order>33 then return end
 local s={weights={},signature=0,rows={},count=0,limit=math.min(limit or 16,16)}
 local weight=1
 for _,name in ipairs(plan.order)do
  if plan.kinds[name]~='bool'and plan.kinds[name]~='float'then return end
  local value=code(values[name]);if not value then return end
  s.weights[name]=weight;s.signature=s.signature+weight*value;weight=weight*3
 end
 return s
end
function K.update(s,name,old,new)
 if s.disabled then return end
 local weight=s.weights[name];if not weight then return end
 local a,b=code(old),code(new)
 if not a or not b then s.disabled=true;s.rows={};s.count=0;return end
 s.signature=s.signature+(b-a)*weight
end
function K.get(s)return not s.disabled and s.rows[s.signature]or nil end
function K.put(s,key,constants)
 if s.disabled or key==''or s.count>=s.limit or s.rows[s.signature]then return false end
 s.rows[s.signature]={key=key,constants=constants};s.count=s.count+1;return true
end
return K
