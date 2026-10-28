-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observations of the admitted native picker, never a second map controller.
local Native=require('src.compat.gen1.NativeSession')
local Modal=require('src.compat.gen1.NativeModalObservation')
local Version=require('src.core.GameVersion')
local Targets=require('src.world.Gen3FlyTargets')
local M={}
local current
local function screen()
 local game=Native.resolve();if not(game and game.stack and type(game.stack.states)=='table')then return end
 local s=Modal.find({'src.ui.Gen3RegionMap'})
 return s and not s.closed and s or nil
end
local function valid(c)
 local r=c and not c.retired and c.refs
 if not(r and r[1]and r[2]and r[6])then return false end
 local game,s=r[1],r[2];local G=package.loaded['src.core.Game3']
 return G and G.native(r[6])==game and Native.game()==game and Version.get()==c.edition
  and game.data==r[3]and game.save==r[4]and game.mods==r[5]and screen()==s
  and s.rsNative==r[7]and(not r[7]or s.rsNative.state==r[8])
end
local function release()
 if current then current.retired=true;current.refs=nil;current.view=nil;current.users={}end
 current=nil
end
local function ready(c)
 if not valid(c)then return false end
 local game,s=c.refs[1],c.refs[2];local stack=game.stack
 local top=stack.active and stack:active()or stack.states[#stack.states]
 if top~=s or s.area then return false end
 if c.refs[7]then
  local raw=c.refs[8];return not c.refs[7].closed and raw.state==12 and raw.inputFn~='move'
 end
 return not s:zooming()
end
local function section(c)
 if not valid(c)then return end
 if c.refs[7]then return c.refs[8].mapSecId end
 local place=c.refs[2]:current();return place and place.section
end
local function destination(c,sec,pos)
 if not valid(c)then return end
 local game,s=c.refs[1],c.refs[2]
 if not s.fly or sec~=section(c)then return end
 if c.refs[7]then
  local rs=c.refs[7];local raw=c.refs[8]
  if pos~=nil and pos~=raw.posWithinMapSec then return end
  local kind=rs.native.mapSecType(raw,sec)
  if kind~=rs.native.TYPE.CITY_CANFLY and kind~=rs.native.TYPE.BATTLE_FRONTIER then return end
  local dest=rs:destination(sec,raw.posWithinMapSec)
  return dest and Targets.detached(game,dest.map,dest)
 end
 if s.frlg and s.page~=(s.playerPage or'kanto')then return end
 return Targets.destination(game,sec,s.targets)
end
function M.active(family)
 local s=screen();local game=Native.game()
 local frlg=Version.isFRLG()
 if not(s and game)then release();return end
 if family and(family=='frlg')~=frlg then return end
 if not valid(current)then
  release();local G=require('src.core.Game3');local view=G.forNative(game)
  if not view then return end
  local rs=s.rsNative
  local c={edition=Version.get(),users={},refs=setmetatable({game,s,game.data,game.save,game.mods,view,rs,rs and rs.state},{__mode='v'})}
  c.view=setmetatable({},{__index=function(_,key)
   if key=='open'then return valid(c)end
   if not valid(c)then return end
   local state=c.refs[2];local raw=c.refs[8]
   if key=='mode'then return state.fly and'fly'or state.area and'area'or'wall'end
   if key=='mapSecId'then return section(c)end
   if raw and(key=='state'or key=='inputFn'or key=='posWithinMapSec'or key=='chose')then return raw[key]end
   -- The generic picker has no fade task: 12 denotes its real input-ready
   -- phase in this observation protocol, rather than an invented timer.
   if key=='state'then return ready(c)and 12 or 0 end
   if key=='inputFn'then return ready(c)and'full'or nil end
   if key=='selectedRegion'then return state.page end
   if key=='playersRegion'then return state.playerPage or(state.frlg and'kanto'or nil)end
   if key=='cursor'then return{x=state.cx,y=state.cy,moveCounter=raw and raw.moveCounter or 0}end
  end,__newindex=function()error('native region map observations are read-only',2)end})
  current=c
 end
 local host=package.loaded['src.mods.Runtime'];local G=package.loaded['src.core.Game3']
 local who=host and host.currentMod or G and G._callbackOwner()
 if who then current.users[who]=true end
 return current.view
end
local function admitted(view)
 return current and valid(current)and(view==nil or view==current.view)and current or nil
end
function M.ready()local c=admitted();return c and ready(c)or false end
function M.section()local c=admitted();return c and section(c)end
function M.destination(sec,pos)
 local c=admitted();if c then return destination(c,sec,pos)end
end
function M.kind(view,sec)
 local c=admitted(view);if not c or sec~=section(c)then return 0 end
 if c.refs[7]then return c.refs[7].native.mapSecType(c.refs[8],sec)end
 -- This older native controller only classifies selectable fly targets.
 -- Do not guess route/city/landmark identities for other atlas sections.
 return destination(c,sec)and 2 or 0
end
M._service={release=release,poll=function()if current and not valid(current)then release()end end,
 releaseOwner=function(_,who)
  if current and current.users[who]then current.users[who]=nil;if not next(current.users)then release()end end
 end}
require('src.core.game3.asset_stream').register(M._service)
return M
