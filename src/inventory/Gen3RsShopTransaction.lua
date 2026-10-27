-- Numeric native presentation IDs are views over the host's stable bag IDs.
local M={};M.__index=M
function M.new(game)
  local self=setmetatable({game=game,items={},token={}},M)
  for id,def in pairs(game.data.items)do if def.index then
    assert(not self.items[def.index],'Duplicate native item number')
    self.items[def.index]={id=id,def=def}
  end end
  local session={version=require('src.core.GameVersion').get(),bag=self.token}
  self.session=setmetatable(session,{
    __index=function(_,key)
      if key=='money'then return game.save.money end
      if key=='gameStats'then return game.save.gen3Stats end
    end,
    __newindex=function(t,key,value)
      if key=='money'then game.save.money=value
      elseif key=='gameStats'then game.save.gen3Stats=value
      else rawset(t,key,value)end
    end})
  return self
end
function M:row(number)return assert(self.items[number],'Unknown native RS shop item '..tostring(number))end
function M:number(id)return assert(self.game.data.items[id].index,'Missing native RS shop item number')end
function M:count(number)return (self.game.save.inventory or {})[self:row(number).id]or 0 end
function M:canAdd(number,qty)
  local save=self.game.save;local copy={inventory={},bagOrder={},gen3PyramidBag=save.gen3PyramidBag,
    gen3RsBagSlots=save.gen3RsBagSlots}
  for id,count in pairs(save.inventory or {})do copy.inventory[id]=count end
  for i,id in ipairs(save.bagOrder or {})do copy.bagOrder[i]=id end
  return require('src.inventory.Bag').add(copy,self:row(number).id,qty,self.game.data)
end
function M:add(number,qty)
  return require('src.inventory.Bag').add(self.game.save,self:row(number).id,qty,self.game.data)
end
function M:remove(number,qty)
  if qty<=0 or self:count(number)<qty then return false end
  local result=require('src.inventory.Bag').remove(self.game.save,self:row(number).id,qty,
    self.game.data,self.selection)
  return result~=false
end
function M:bindings()
  local function bag(token)assert(token==self.token,'Mixed RS shop inventory')end
  return {
    get=function(token,n)bag(token);return self:count(n)end,
    canAdd=function(token,n,q)bag(token);return self:canAdd(n,q)end,
    add=function(token,n,q)bag(token);return self:add(n,q)end,
    remove=function(token,n,q)bag(token);return self:remove(n,q)end,
  }
end
return M
