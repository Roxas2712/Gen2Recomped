-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GSC collision-class permission queries, independent of later-gen blocking
-- bits. Actual walking still uses the active map's imported permission sets.
local M={LAND=0,WATER=1,WALL=15}
local walls={[7]=true,[15]=true,[0x12]=true,[0x15]=true,[0x1a]=true,
 [0x1d]=true,[0x27]=true,[0x2f]=true,[0x62]=true,[0x6a]=true,[0xff]=true}
function M.of(coll)
 if type(coll)~='number' or coll<0 or coll%1~=0 then return M.WALL end
 local n=coll%256
 if walls[n] or n>=0x80 and n<=0x84 or n>=0x88 and n<=0x8c
   or n>=0x90 and n<=0x9f then return M.WALL end
 if n>=0x20 and n<=0x2e and n~=0x23 and n~=0x27 and n~=0x2b
   or n>=0x30 and n<=0x3f or n>=0xc0 and n<=0xcf then return M.WATER end
 return M.LAND
end
function M.isLand(coll)return M.of(coll)==M.LAND end
function M.isWater(coll)return M.of(coll)==M.WATER end
function M.isWall(coll)return M.of(coll)==M.WALL end
M.isWalkable=M.isLand
function M.isLedge(coll)
 return type(coll)=='number' and coll>=0 and coll%1==0 and math.floor(coll%256/16)==0xa
end
function M.surfable(coll)
 local permission=M.of(coll)
 if permission==M.WATER then return 'water' end
 if permission==M.LAND then return 'land' end
end
return M
