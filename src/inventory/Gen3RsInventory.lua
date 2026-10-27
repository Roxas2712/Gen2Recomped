-- Stable host IDs remain authoritative. The pinned RS policy/controller owns
-- physical slots; its numeric IDs never enter the serialized host save.
local M = {}
local Loader = require('compat.gen1-rs.Loader')
local HOST = {ITEM='ITEMS', BALL='POKE_BALLS', TM_HM='TM_CASE',
  BERRY='BERRY_POUCH', KEY_ITEM='KEY_ITEMS'}
local contexts=setmetatable({},{__mode='k'})

local function integer(n)
  return type(n)=='number' and n==n and n<math.huge and n>=0 and n%1==0
end
local function badge(id) return type(id)=='string' and id:find('BADGE',1,true) end
local function context(data,save)
  local spec=data and data.constants and data.constants.gen3RsBag
  if not (type(spec)=='table' and spec.format==1
    and (spec.version=='ruby' or spec.version=='sapphire')) or save.gen3PyramidBag then return end
  local configured=data.constants.gen3Bag and data.constants.gen3Bag.pockets or {}
  local signature={}
  for _,p in ipairs({'ITEM','BALL','TM_HM','BERRY','KEY_ITEM'})do signature[#signature+1]=tostring(configured[p])end
  signature=table.concat(signature,':')
  local cached=contexts[data]
  if cached and cached.items==data.items and cached.spec==spec and cached.version==spec.version
    and cached.signature==signature then return cached end
  local load=Loader.new(spec.version)
  local policy=load('src.core.game3.profiles.rs.bag')
  local byNumber,byId={},{}
  for id,def in pairs(data.items or {}) do
    if type(id)=='string' and integer(def.index) and def.index>0 then
      if byNumber[def.index] then return end
      byNumber[def.index]=id;byId[id]=def.index
    end
  end
  for host,native in pairs(HOST) do
    local cap=configured[host]
    if integer(cap) and cap>0 then policy.capacity[native]=cap end
  end
  local function stable(id) return type(id)=='number' and byNumber[id] or id end
  local function pocket(id)
    local def=data.items[stable(id)] or {}
    return HOST[def.pocket] or def.pocket
  end
  load=Loader.new(spec.version,{
    __package={loaded={}},
    ['src.core.game3.items']={GAME3_MAX_QTY=999,FRLG_TO_HOST=byNumber,
      clampGame3=function(n)return math.max(0,math.min(999,math.floor(tonumber(n)or 0)))end},
    ['src.core.game3.items_data']={
      toNumericId=function(id)return type(id)=='number' and id or byId[id] or 0 end,
      bagKey=stable,pocketOf=pocket,CAPACITY=policy.capacity,BAG_MODEL=policy,
      CONTAINERS={},slotMax=function(p)return policy.slotMax[p]or policy.slotMax.default end,
      isHm=function(id)local d=data.items[stable(id)]or{};return d.machine and d.machine.kind=='HM'end,
    },
  })
  local c={native=load('src.core.game3.bag'),policy=policy,version=spec.version,
    byId=byId,stable=stable,pocket=pocket,items=data.items,spec=spec,signature=signature}
  contexts[data]=c;return c
end

local function totals(c,bag)
  local out={}
  for _,p in ipairs(c.policy.pockets)do
    for _,slot in ipairs(bag.pockets[p])do
      local id=c.stable(slot.id);out[id]=(out[id]or 0)+slot.qty
    end
  end
  return out
end

local function savedBag(c,snapshot)
  if type(snapshot)~='table' or snapshot.format~=1 or snapshot.version~=c.version
    or type(snapshot.pockets)~='table' then return end
  local bag=c.native.new()
  for _,p in ipairs(c.policy.pockets)do
    local slots=snapshot.pockets[p]
    if type(slots)~='table' or #slots>c.policy.capacity[p] then return end
    local seen={}
    for i,s in ipairs(slots)do
      if type(s)~='table' or not c.byId[s.id] or c.pocket(s.id)~=p
        or not integer(s.qty) or s.qty<1 or s.qty>(c.policy.slotMax[p]or c.policy.slotMax.default)
        or (seen[s.id]and not c.policy.splitSlots[p]) then return end
      seen[s.id]=true;bag.pockets[p][i]={id=c.byId[s.id],qty=s.qty}
    end
  end
  return bag
end

-- Projection and preflight only modify private copies. Merely opening/drawing
-- a bag, loading an old save, or asking whether a purchase fits writes nothing.
local function project(c,save)
  local inv=save.inventory or {}
  for id,qty in pairs(inv)do
    if not badge(id) and (not c.byId[id]or not c.policy.capacity[c.pocket(id)]
      or not integer(qty)or qty<1)then return end
  end
  local bag=savedBag(c,save.gen3RsBagSlots)or c.native.new()
  local have=totals(c,bag)
  for id,qty in pairs(have)do
    local wanted=inv[id]or 0
    if wanted<qty and not c.native.remove(bag,id,qty-wanted)then return end
  end
  have=totals(c,bag)
  local order,seen={},{}
  for _,id in ipairs(save.bagOrder or {})do
    if inv[id]and not badge(id)and not seen[id]then order[#order+1]=id;seen[id]=true end
  end
  local extra={}
  for id in pairs(inv)do if not badge(id)and not seen[id]then extra[#extra+1]=id end end
  table.sort(extra)
  for _,id in ipairs(extra)do order[#order+1]=id end
  for _,id in ipairs(order)do
    local missing=inv[id]-(have[id]or 0)
    if missing>0 and not c.native.add(bag,id,missing)then return end
  end
  return bag
end

local function commit(c,save,bag)
  local counts=totals(c,bag)
  local inv=save.inventory
  for id in pairs(inv)do if not badge(id)then inv[id]=nil end end
  for id,qty in pairs(counts)do inv[id]=qty end
  local order=save.bagOrder or {};save.bagOrder=order
  local seen={}
  for i=#order,1,-1 do
    local id=order[i]
    if not counts[id]or seen[id]then table.remove(order,i)else seen[id]=true end
  end
  local snapshot={format=1,version=c.version,pockets={}}
  for _,p in ipairs(c.policy.pockets)do
    snapshot.pockets[p]={}
    local unique,present={},{}
    for i,s in ipairs(bag.pockets[p])do
      local id=c.stable(s.id)
      snapshot.pockets[p][i]={id=id,qty=s.qty}
      if not seen[id]then order[#order+1]=id;seen[id]=true end
      if not present[id]then unique[#unique+1]=id;present[id]=true end
    end
    -- The legacy ID-only acquisition view keeps its table identity and its
    -- interleaved pockets, while reflecting each pocket's physical order.
    local index=1
    for i,id in ipairs(order)do if c.pocket(id)==p then
      order[i]=assert(unique[index]);index=index+1
    end end
  end
  save.gen3RsBagSlots=snapshot
end

function M.rows(save,data,pocket)
  local c=context(data,save);if not c then return end
  local bag=project(c,save);pocket=HOST[pocket]or pocket
  if not bag or not bag.pockets[pocket]then return end
  local rows={}
  for i,s in ipairs(bag.pockets[pocket])do rows[i]={id=c.stable(s.id),qty=s.qty,
    slot={pocket=pocket,index=i,id=c.stable(s.id)}}end
  return rows
end
function M.stackLimit(data,id)
  local c=context(data,{});if c and c.byId[id]then
    return c.policy.slotMax[c.pocket(id)]or c.policy.slotMax.default
  end
end

local function remove(c,bag,id,qty,selection)
  if selection then
    local slots=bag.pockets[selection.pocket]
    local slot=slots and slots[selection.index]
    if selection.id~=id or not slot or c.stable(slot.id)~=id then return false end
    return c.native.removeSlot(bag,selection.pocket,selection.index,qty)
  end
  return c.native.remove(bag,id,qty)
end
local function mutation(save,data,id,qty,kind,selection)
  local c=context(data,save)
  if not c or badge(id)or not c.byId[id]then return false end
  if not integer(qty)or qty<1 then return true,false end
  local bag=project(c,save);if not bag then return true,false end
  local ok
  if kind=='add'then ok=c.native.add(bag,id,qty)
  else ok=remove(c,bag,id,qty,selection)end
  if ok then commit(c,save,bag)end
  return true,ok
end
function M.add(save,data,id,qty)return mutation(save,data,id,qty,'add')end
function M.remove(save,data,id,qty,selection)return mutation(save,data,id,qty,'remove',selection)end
function M.swap(save,data,first,second)
  local c=context(data,save);if not c then return false end
  local bag=project(c,save)
  if not bag or not first or not second or first.pocket~=second.pocket
    or c.policy.sortById[first.pocket]then return true,false end
  local slots=bag.pockets[first.pocket]
  local a,b=slots and slots[first.index],slots and slots[second.index]
  if not a or not b or c.stable(a.id)~=first.id or c.stable(b.id)~=second.id then return true,false end
  slots[first.index],slots[second.index]=b,a
  commit(c,save,bag);return true,true
end
function M.giveHeld(save,data,mon,id,selection)
  local c=context(data,save);if not c or not c.byId[id]then return false end
  local bag=project(c,save);local previous=mon.item
  if not bag or not remove(c,bag,id,1,selection)then return true,false end
  if previous and (not c.byId[previous]or not c.native.add(bag,previous,1))then return true,false end
  commit(c,save,bag);mon.item=id;return true,true,previous
end

-- Check the actual persisted mirror, without reconciling it first.
function M.consistent(save,data)
  local c=context(data,save);if not c then return false end
  local bag=savedBag(c,save.gen3RsBagSlots);if not bag then return false end
  local counts=totals(c,bag)
  for id,qty in pairs(save.inventory or {})do if not badge(id)and counts[id]~=qty then return false end end
  for id,qty in pairs(counts)do if save.inventory[id]~=qty then return false end end
  return true
end
return M
