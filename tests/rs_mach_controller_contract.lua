local M=require('src.world.Gen3RsMach')
local n=0
local function check(v,why)n=n+1;assert(v,why)end
local durations={16,8,4}
local function step(p,input)
  local mode,dir=M.intent(p,input)
  if mode=='face'then M.clear(p);p.rsMachRunning='still';return mode,dir end
  if mode=='turn'then M.clear(p);p.facing=dir;p.rsMachRunning='turn';return mode,dir end
  M.begin(p,mode,dir)
  local frames=durations[(p.bikeCounter or 0)+1]
  p.facing=dir;M.arrived(p)
  return mode,dir,frames
end
for _,dir in ipairs({'up','down','left','right'})do
  for run=1,6 do
    local p={facing=dir}
    for i=1,run do
      local mode,travel,frames=step(p,dir)
      check(mode=='accelerate'and travel==dir and frames==durations[math.min(i,3)],'Acceleration duration')
    end
    local expected=run==1 and{}or(run==2 and{16}or{4,8,16})
    for _,frames in ipairs(expected)do
      local mode,travel,time=step(p,nil)
      check(mode=='coast'and travel==dir and time==frames,'Actual coasting tile duration')
    end
    check(step(p,nil)=='face'and p.bikeCounter==0 and p.rsMachSpeed==0,'Stop after finite coast')
    local _,_,frames=step(p,dir);check(frames==16,'Restart uses first rung')
  end
end
local p={facing='right'}
for i=1,3 do step(p,'right')end
local mode,dir,frames=step(p,'up')
check(mode=='accelerate'and dir=='up'and frames==4,'A continuously moving corner keeps speed')
step(p,nil);step(p,nil);step(p,nil);step(p,nil)
mode,dir,frames=step(p,'left')
check(mode=='turn'and dir=='left'and frames==nil,'A stopped corner turns in place')
local _,_,frames=step(p,'left');check(frames==16,'First tile after a standing turn')
for i=1,3 do step(p,'left')end
step(p,nil)
local _,_,frames=step(p,'right');check(frames==4,'Coasting can be interrupted by a moving turn')
M.clear(p);check(p.rsMachSpeed==0 and p.bikeCounter==0 and not p.rsMachStep,'Collision clears run and pending step')
M.arrived(p);check(p.bikeCounter==0,'Scripted/duplicate arrivals cannot create speed')
print('RS_MACH_CONTROLLER_CHECKS',n)
