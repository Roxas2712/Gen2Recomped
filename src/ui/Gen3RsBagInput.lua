-- RS list navigation around the host's existing inventory/action callbacks.
local M = {}
local positions = setmetatable({}, {__mode='k'})

local function play(bag) require('src.core.Sound').play(bag.game.data,'Press_AB') end
local function remember(bag)
  local p=positions[bag.game.save] or {}
  positions[bag.game.save]=p
  p[bag.pocket]={index=bag.index,top=bag.top}
end

function M.restore(bag)
  local p=positions[bag.game.save]
  local old=p and p[bag.pocket]
  if old then
    bag.index=math.max(1,math.min(#bag.rows,old.index))
    bag.top=math.max(1,math.min(old.top,math.max(1,#bag.rows-7)))
  end
end

local function direction(bag,input)
  local held
  for _,key in ipairs({'up','down','left','right'}) do
    if input:wasPressed(key) then bag.rsHeld,bag.rsHeldFrames=key,0 return key end
    if not held and input.isDown and input:isDown(key) then held=key end
  end
  if held~=bag.rsHeld then bag.rsHeld,bag.rsHeldFrames=held,0 return end
  if held then
    bag.rsHeldFrames=(bag.rsHeldFrames or 0)+1
    if bag.rsHeldFrames>=40 and (bag.rsHeldFrames-40)%5==0 then return held end
  end
end

function M.update(bag,input)
  if not bag.rsInitialized then
    bag.rsInitialized=true
    M.restore(bag)
    bag.rsOpen=0
  end
  if bag.rsBall then
    bag.rsBall.k=bag.rsBall.k+1
    if bag.rsBall.k>=32 then bag.rsBall=nil end
  end
  if bag.rsDrop then bag.rsDrop=bag.rsDrop+1 if bag.rsDrop>=10 then bag.rsDrop=nil end end
  if bag.rsOpen then
    bag.rsOpen=bag.rsOpen+1
    if bag.rsOpen>=16 then bag.rsOpen=nil end
    return
  end
  if bag.rsToss then return bag.rsView:updateToss(input)end
  if bag.rsDeposit then return bag.rsView:updateDeposit(input)end
  local key=direction(bag,input)
  if bag.rsSwitch then
    bag.rsSwitch=bag.rsSwitch+1
    if bag.rsSwitch>=16 then bag.rsSwitch=nil end
    return
  end
  if key=='up' or key=='down' then
    local old=bag.index
    bag.index=math.max(1,math.min(#bag.rows,old+(key=='down' and 1 or -1)))
    if bag.index<bag.top then bag.top=bag.index end
    if bag.index>bag.top+7 then bag.top=bag.index-7 end
    if old~=bag.index then bag.message=nil;bag.rsShake=bag.tick;play(bag) end
    remember(bag)
    return
  end
  if bag.rsSwap then
    if input:wasPressed('b') or (input:wasPressed('a') and (not bag:selected() or bag:selected().close)) then
      bag.rsSwap=nil;play(bag)
    elseif input:wasPressed('a') or input:wasPressed('select') then
      local first,second=bag.rows[bag.rsSwap],bag:selected()
      if first and first.id and second and second.id then
        local handled=require('src.inventory.Gen3RsInventory').swap(
          bag.game.save,bag.game.data,first.rsSlot,second.rsSlot)
        if not handled then
          local order=require('src.inventory.Bag').order(bag.game.save)
          local a,b
          for i,id in ipairs(order) do if id==first.id then a=i end if id==second.id then b=i end end
          if a and b then order[a],order[b]=order[b],order[a] end
        end
        bag:rebuild()
      end
      bag.rsSwap=nil;play(bag)
    end
    return
  end
  if (key=='left' or key=='right') and not bag.lockPocket then
    remember(bag)
    local dir=key=='right' and 1 or -1
    bag:movePocket(dir)
    M.restore(bag)
    bag.rsSwitch,bag.rsBall,bag.rsDrop=0,{k=0,dir=dir},0
    play(bag)
    return
  end
  if input:wasPressed('select') and not bag.pick and not bag.sell and not bag.store
    and bag.pocket~=3 and bag.pocket~=4 and bag:selected() and not bag:selected().close then
    bag.rsSwap=bag.index;play(bag)
  elseif input:wasPressed('a') then
    remember(bag)
    if not(bag.store=='deposit'and bag.rsPcTransaction)then play(bag)end
    bag:choose()
  elseif input:wasPressed('b') then remember(bag);play(bag);bag:close() end
end

return M
