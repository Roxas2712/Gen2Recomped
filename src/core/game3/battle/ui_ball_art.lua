-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source-owned views of the imported native ball sheet. No ball timeline is
-- created, and releasing source art cannot invalidate the native asset cache.
local Battle=require('src.core.game3.battle')
local Assets=require('src.render.Assets')
local Call=require('src.compat.gen1.SourceCall')
local M={}
local current
local function release()
 if current then
  for _,quad in pairs(current.quads)do quad:release()end
  if current.image then current.image:release()end
 end
 current=nil
end
local function integer(n)return type(n)=='number'and n==n and n%1==0 and n>=0 and n<math.huge end
local function context()
 local screen=Battle._screen();local view=screen and Battle.getState()
 if not screen then release();return end
 local r=screen.data.constants.gen3BallAnim
 local path=r and r.images and r.images.balls
 if type(path)~='string'then release();return end
 local size,frames=r.size,r.frames
 if not(integer(size)and size>0 and integer(frames)and frames>0)then release();return end
 if current and(current.view~=view or current.path~=path or current.size~=size or current.frames~=frames)then release()end
 if not current then current={view=view,path=path,size=size,frames=frames,quads={},users={}}end
 return current
end
function M.quad(ball,frame)
 local c=context();if not c then return nil,'native ball artwork unavailable'end
 if not(integer(ball)and integer(frame)and frame<c.frames)then return nil,'invalid native ball cell'end
 local owner=Call.owner(M,'quad')or'engine';c.users[owner]=true
 if not c.image then
  local ok,image=pcall(love.graphics.newImage,Assets.resolve(c.path))
  if not ok then return nil,tostring(image)end
  c.image=image
 end
 local w,h=c.image:getDimensions()
 if w~=c.frames*c.size or h%c.size~=0 or ball>=h/c.size then return nil,'native ball cell outside imported sheet'end
 local key=ball*c.frames+frame
 local quad=c.quads[key]
 if not quad then
  quad=love.graphics.newQuad(frame*c.size,ball*c.size,c.size,c.size,w,h)
  c.quads[key]=quad
 end
 return c.image,quad
end
M._service={release=release,poll=function()if current then context()end end,
 releaseOwner=function(_,who)
  if current then current.users[who]=nil;if not next(current.users)then release()end end
 end}
require('src.core.game3.asset_stream').register(M._service)
Assets.register(release)
return M
