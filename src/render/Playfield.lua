-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe the native frame's reserved game rectangle. Ordinary touch overlays
-- remain the layout caller's concern; this does not install a skin or viewport.
local Viewport=require('src.render.GameViewport')
local P={}
local function dimension(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function P.cutout(w,h)
 if not(dimension(w)and dimension(h))or not Viewport.inFrame or not Viewport.active()then return nil end
 local fullW,fullH=Viewport.fullDimensions()
 local r=Viewport.rect
 if not r or r.x==0 and r.y==0 and r.width==fullW and r.height==fullH then return nil end
 local localW,localH=Viewport.dimensions()
 if w==localW and h==localH then
  -- The native owner has already entered its local canvas. Do not subtract
  -- the window-space origin twice or discard the right/bottom edge again.
  return 0,0,localW,localH
 end
 if w==fullW and h==fullH then return r.x,r.y,r.width,r.height end
 -- A preview/actor capture of another size has no native window cutout.
 return nil
end
return P
