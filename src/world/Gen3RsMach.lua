-- RS keeps the next acceleration rung separately from its remaining coast.
-- These values advance at movement boundaries, never on a draw/idle tick.
local M={}
function M.clear(p)
  p.bikeCounter=0;p.rsMachSpeed=0;p.rsMachStep=nil
end
function M.intent(p,dir)
  local previous=p.facing
  local speed=tonumber(p.rsMachSpeed)or 0
  if not dir then
    if speed==0 then return 'face',previous end
    return 'coast',previous
  end
  if dir~=previous and p.rsMachRunning~='moving'then
    if speed>0 then return 'coast',previous end
    return 'turn',dir
  end
  return 'accelerate',dir
end
function M.begin(p,mode,dir)
  p.rsMachRunning='moving';p.turnArmed=false
  if mode=='coast'then
    p.rsMachSpeed=math.max(0,(tonumber(p.rsMachSpeed)or 0)-1)
    p.bikeCounter=p.rsMachSpeed
  end
  p.rsMachStep={mode=mode,counter=p.bikeCounter or 0,dir=dir}
end
function M.arrived(p)
  local step=p.rsMachStep;p.rsMachStep=nil
  if not step then return end -- scripted travel/ledges do not accelerate
  if step.mode=='accelerate'then
    p.rsMachSpeed=step.counter+math.floor(step.counter/2)
    p.bikeCounter=math.min(2,step.counter+1)
  end
  p.bikeLastDir=step.dir
end
return M
