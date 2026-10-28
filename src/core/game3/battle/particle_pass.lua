-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Borrow actual native OBJ/copy painters in the caller's battler bands.
local Battle=require('src.core.game3.battle')
local Native=require('src.battle.Gen3Battle')
local Coords=require('src.core.game3.battle.anim_coords')
local Scope=require('src.render.GraphicsScope')
local Assets=require('src.render.Assets')
local M={}
local current
local function retire()
 if current then current.refs[1]=nil;current.view=nil;current.rows=nil;current.users={} end
 current=nil
end
local function live(c)
 local screen=c.refs[1]
 return screen and Battle._screen()==screen and Battle.getState()==c.view
  and screen.gen3Anim==c.refs[2] and screen.gen3AnimPlaying
end
local function context(owner)
 local screen=Battle._screen();local anim=screen and screen.gen3AnimPlaying and screen.gen3Anim
 if not anim then retire();return end
 if current and not live(current) then retire() end
 if not current then current={refs=setmetatable({screen,anim},{__mode='v'}),view=Battle.getState(),users={}} end
 if owner then current.users[owner]=true end
 return current,screen,anim
end
local function sample(c,screen,anim)
 local token=Scope.token()
 if token and c.rows and c.token==token and c.frame==anim.frame and c.serial==anim.presentationSerial then return c.rows end
 local rows={};local order=Coords.monDrawOrder(c.view);local slot={}
 for i,id in ipairs(order)do slot[id]=i end
 local function add(kind,value,z)rows[#rows+1]={kind=kind,value=value,z=z}end
 local function copies(phase,z)
  for _,copy in ipairs(anim.monBgCopies and anim:monBgCopies(screen,phase)or{})do add('copy',copy,z)end
 end
 copies('pre',50)
 c.residual=nil
 local objects,bgs=Native.moveOamObjects(screen,true)
 if objects then
  local band=0
  for priority=3,0,-1 do
   for _,copy in ipairs(bgs)do if (tonumber(copy.priority)or 2)==priority then add('copy',copy,band*100+50)end end
   for i=#objects,1,-1 do
    local row=objects[i]
    if math.floor(row.key/256)==priority then
     if row.kind=='battler' then
      local b=row.battler;local id=b.position or(b==screen.player and 0 or 1)
      band=slot[id]or band
     else add('event',row,band*100+50)end
    end
   end
  end
 else
  -- Native task/helper barriers without a complete OAM key retain the native
  -- fallback: actual event order above the battlers, not invented priorities.
  c.residual=bgs
  for _,copy in ipairs(anim.monBgCopies and anim:monBgCopies(screen,'oam')or{})do add('copy',copy,50)end
  for _,row in ipairs(anim:eventsForDraw(screen,Native))do add('event',row,999)end
 end
 copies('post',999)
 -- Surf and flourish keep their own native task/graphics implementations.
 -- skipEvents prevents this borrowed extra layer from redrawing OBJ events.
 add('extras',true,999)
 c.token,c.frame,c.serial,c.rows=token,anim.frame,anim.presentationSerial,rows
 return rows
end
local function bound(n,default)
 if n==nil then return default end
 assert(type(n)=='number' and n==n and math.abs(n)<math.huge,'particle band must be finite')
 return n
end
function M.draw(lo,hi,owner)
 lo,hi=bound(lo,0),bound(hi,999);if lo>hi then return false,'empty particle band' end
 local c,screen,anim=context(owner);if not c then return false,'inactive native animation' end
 local rows=sample(c,screen,anim);local count=0
 local ok,result,reason=Scope.call(function()
  for _,row in ipairs(rows)do
   if row.z>=lo and row.z<=hi then
    if not live(c) or screen.gen3Anim~=anim or anim.frame~=c.frame then retire();return false,'native particle admission changed' end
    if row.kind=='event' then
     local entry=row.value;anim:drawEvent(entry.event,screen,Native,Assets,entry.pose,true)
    elseif row.kind=='copy' then screen:drawGen3MonBgState(row.value)
    else anim:draw(screen,true) end
    if not live(c) or screen.gen3Anim~=anim or anim.frame~=c.frame then retire();return false,'native particle admission changed' end
    count=count+1
   end
  end
  return true,count
 end)
 if not ok then error(result,0)end
 return result,reason
end
M._service={release=retire,poll=function()if current and not live(current)then retire()end end,
 releaseOwner=function(_,owner)if current and current.users[owner]then retire()end end}
require('src.core.game3.asset_stream').register(M._service)
return M
