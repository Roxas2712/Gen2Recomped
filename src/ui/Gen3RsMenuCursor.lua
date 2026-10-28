-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Outline placement follows the cartridge cursor composition recorded by
-- the pinned RS common-UI importer. Images belong to the native Assets owner.
local Assets=require('src.render.Assets')
local Scope=require('src.render.GraphicsScope')
local Session=require('src.compat.gen1.NativeSession')
local Version=require('src.core.GameVersion')
local M={}
local manifests=setmetatable({},{__mode='k'})
local plans,order={},{}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function plan(width)
 assert(finite(width)and width%1==0 and width>=1 and width<=4096,'invalid native RS cursor width')
 if plans[width]then return plans[width]end
 -- Interior strips cover 32 pixels at a time. A final partial wide strip
 -- overlaps the preceding one; the right cap always starts at width-7.
 local out={{part='left',x=-1}}
 local wide=math.floor((width-1)/32)
 for i=0,wide-1 do out[#out+1]={part='wide',x=1+i*32}end
 local rest=(width-1)%32;local advance=1+wide*32
 local tiles=math.floor(rest/8)
 if width>39 and rest>8 then
  out[#out+1]={part='wide',x=advance-32+tiles*8}
 else for i=0,tiles-1 do out[#out+1]={part='middle',x=advance+i*8}end end
 out[#out+1]={part='right',x=width-7}
 if #order==16 then plans[table.remove(order,1)]=nil end
 order[#order+1]=width;plans[width]=out
 return out
end
function M.segments(width)
 local copy={};for i,row in ipairs(plan(width))do copy[i]={part=row.part,x=row.x}end
 return copy
end
function M.available(game)
 local version=Version.get()
 if version~='ruby'and version~='sapphire'then return false end
 local c=game and game.data and game.data.constants
 local spec=c and c.gen3RsBag
 return type(spec)=='table'and spec.format==1 and spec.version==version
  and type(spec.common)=='string'and spec.common=='data/generated/gba/rse/common_ui/manifest.lua'and spec or false
end
local function resources(game)
 local spec=assert(M.available(game),'native RS common UI unavailable')
 local cached=manifests[spec]
 if cached and cached.path==spec.common and cached.version==spec.version then return cached.parts end
 local chunk=assert(love.filesystem.load(spec.common),'native RS common UI manifest missing')
 setfenv(chunk,{})
 local manifest=chunk()
 assert(type(manifest)=='table'and manifest.layout=='rs'and manifest.game==spec.version,
  'mixed-edition native RS cursor manifest')
 local cursor=manifest.menuCursor
 assert(type(cursor)=='table','native RS cursor metadata missing')
 local parts=cursor.parts or cursor;local paths={}
 for _,name in ipairs{'left','middle','wide','right'}do
  local part=parts[name];local width=name=='wide'and 32 or 8
  assert(type(part)=='table'and type(part.png)=='string'and part.w==width and part.h==16,
   'invalid native RS cursor part '..name)
  assert(Assets.exists(part.png),'native RS cursor image missing: '..part.png)
  paths[name]=part.png
 end
 manifests[spec]={path=spec.common,version=spec.version,parts=paths}
 return paths
end
function M.paint(game,x,y,width,fx)
 assert(finite(x)and finite(y),'invalid native RS cursor position')
 local rows=plan(width)
 local current=Session.game()
 if not current or current~=game or(Version.get()~='ruby'and Version.get()~='sapphire')then
  return false,'no current native RS cursor owner'
 end
 local parts=resources(game)
 local images={}
 for _,name in ipairs{'left','middle','wide','right'}do
  local image=assert(Assets.image(parts[name]),'native RS cursor image unavailable')
  local w,h=image:getDimensions()
  -- Native images may have higher texel density while retaining logical size.
  local logical=name=='wide'and 32 or 8
  assert(w>=logical and h>=16 and w/logical==h/16,'invalid native RS cursor image density')
  images[name]={image=image,scale=logical/w}
 end
 local ok,why=Scope.call(function()
  local g=love.graphics;local Fx=require('src.core.game3.gba_fx')
  for i=#rows,1,-1 do
   local row=rows[i];local image=images[row.part]
   Fx.draw(function()
    g.setColor(1,1,1,1);g.draw(image.image,x+row.x,y,0,image.scale,image.scale)
   end,fx)
  end
 end)
 if not ok then error(why,0)end
 return true
end
function M.draw(x,y,width,fx)return M.paint(Session.game(),x,y,width,fx)end
function M.forGame(game)
 local owner=setmetatable({game},{__mode='v'})
 return{draw=function(x,y,width,fx)return M.paint(owner[1],x,y,width,fx)end}
end
M._service={release=function()manifests=setmetatable({},{__mode='k'});plans,order={},{}end}
M._service.releaseOwner=M._service.release
Assets.register(M._service.release)
require('src.core.game3.asset_stream').register(M._service)
return M
