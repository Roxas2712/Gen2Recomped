-- Atomic transfers between stable host IDs and the original RS PC list.
local M={};M.__index=M
local Bag=require('src.inventory.Bag')
local function integer(n)return type(n)=='number'and n==n and n<math.huge and n>0 and n%1==0 end
local function copyBag(save)
  local copy={inventory={},bagOrder={},gen3RsBagSlots=save.gen3RsBagSlots,gen3PyramidBag=save.gen3PyramidBag}
  for id,q in pairs(save.inventory or{})do copy.inventory[id]=q end
  for i,id in ipairs(save.bagOrder or{})do copy.bagOrder[i]=id end
  return copy
end
local function replace(target,source)
  for k in pairs(target)do target[k]=nil end
  for k,v in pairs(source)do target[k]=v end
end
function M.new(game,options)
  local self=setmetatable({game=game,byNumber={},byId={},token={}},M)
  local version=options and options.version or game.data.constants.gen3RsBag.version
  assert(version=='ruby'or version=='sapphire'or version=='emerald')
  self.session={version=version,bag=self.token,name=(game.save.player or{}).name}
  for id,d in pairs(game.data.items or{})do if integer(d.index)then
    assert(not self.byNumber[d.index],'Duplicate native PC item number')
    self.byNumber[d.index]=id;self.byId[id]=d.index
  end end
  local load=require('compat.gen1-rs.Loader').new(version,{
    __package={loaded={}},['src.core.game3.items_data']={},['src.core.game3.bag']={},
    ['src.core.game3.profile']={forSession=function()return {bag=self.policy}end},
  })
  self.policy=options and options.pcLimits or load('src.core.game3.profiles.rs.bag')
  self.nativeStorage=load('src.core.game3.storage')
  -- Only the native PC item transaction is used; no Pokémon box defaults,
  -- heal effects or mutable reference session are projected into the host.
  self.nativeStorage.ensure=function(s)assert(s==self.session);return assert(self.candidate)end
  self:refresh();return self
end
function M:id(n)return type(n)=='number'and self.byNumber[n]or n end
function M:number(id)return self.byId[id]end
function M:snapshot()
  local pc=self.game.save.pcItems or{};local seen,list={},{}
  local function append(id)
    local qty=pc[id]
    if not self.byId[id]or not integer(qty)or qty>self.policy.pcSlotMax then return false end
    list[#list+1]={id=self.byId[id],qty=qty};seen[id]=true;return true
  end
  for _,id in ipairs(self.game.save.pcOrder or{})do
    if pc[id]and not seen[id]and not append(id)then return end
  end
  local extra={}
  for id in pairs(pc)do if not seen[id]then extra[#extra+1]=id end end
  table.sort(extra,function(a,b)
    local na,nb=self.byId[a]or math.huge,self.byId[b]or math.huge
    if na~=nb then return na<nb end;return tostring(a)<tostring(b)
  end)
  for _,id in ipairs(extra)do if not append(id)then return end end
  if #list>self.policy.pcItems then return end
  return list
end
function M:refresh()
  local list=self:snapshot();self.valid=list~=nil
  self.store={items=list or{}};return self.valid
end
function M:commitPC(list)
  local save=self.game.save;local pc,order={},{}
  for i,row in ipairs(list)do local id=assert(self:id(row.id));pc[id]=row.qty;order[i]=id end
  save.pcItems=save.pcItems or{};save.pcOrder=save.pcOrder or{}
  replace(save.pcItems,pc);replace(save.pcOrder,order)
end
function M:commitBag(copy)
  local save=self.game.save;save.inventory=save.inventory or{};save.bagOrder=save.bagOrder or{}
  replace(save.inventory,copy.inventory);replace(save.bagOrder,copy.bagOrder)
  save.gen3RsBagSlots=copy.gen3RsBagSlots
end
function M:canWithdraw(n,qty)
  local id=self:id(n);local list=self:snapshot()
  if not list or not id or not integer(qty)or((self.game.save.pcItems or{})[id]or 0)<qty then return false end
  return Bag.add(copyBag(self.game.save),id,qty,self.game.data)
end
function M:withdraw(n,qty)
  local id=self:id(n);local list=self:snapshot()
  if not list or not id or not integer(qty)then return false end
  local found
  for i,row in ipairs(list)do if row.id==self:number(id)then found=i;break end end
  if not found or list[found].qty<qty then return false end
  local copy=copyBag(self.game.save)
  if not Bag.add(copy,id,qty,self.game.data)then return false end
  list[found].qty=list[found].qty-qty;if list[found].qty==0 then table.remove(list,found)end
  self:commitBag(copy);self:commitPC(list);return true
end
function M:deposit(selection,qty)
  local id=selection and selection.id;local list=self:snapshot()
  local def=id and self.game.data.items[id]
  if not list or not def or tonumber(def.importance)==2 or not integer(qty)or qty>999 then return false end
  local copy=copyBag(self.game.save)
  if not Bag.remove(copy,id,qty,self.game.data,selection)then return false end
  self.candidate={items=list}
  local ok=self.nativeStorage.addPcItem(self.session,assert(self:number(id)),qty)
  self.candidate=nil
  if not ok then return false end
  self:commitBag(copy);self:commitPC(list)
  if not self.game.save.inventory[id]and self.game.save.registeredItem==id then self.game.save.registeredItem=nil end
  return true
end
function M:toss(n,qty)
  local id=self:id(n);local def=id and self.game.data.items[id];local list=self:snapshot()
  if not list or not def or(tonumber(def.importance)or 0)~=0 or not integer(qty)then return false end
  for i,row in ipairs(list)do if row.id==self:number(id)then
    if row.qty<qty then return false end
    row.qty=row.qty-qty;if row.qty==0 then table.remove(list,i)end
    self:commitPC(list);return true
  end end
  return false
end
function M:reorder()
  local canonical=self:snapshot();if not canonical or #canonical~=#self.store.items then return false end
  local byId={};for _,row in ipairs(canonical)do byId[row.id]=row.qty end
  for _,row in ipairs(self.store.items)do
    if byId[row.id]~=row.qty then return false end;byId[row.id]=nil
  end
  if next(byId)then return false end
  self:commitPC(self.store.items);return true
end
return M
