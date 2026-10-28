-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local J=require('src.link.Json')
local rows={{{72,80},{176,40},{48,40},{112,80}},{{32,80},{200,40},{90,88},{152,32}}}
for _,e in ipairs{{'ruby',0x37f578,0x77abc},{'sapphire',0x37f508,0x77ac0}}do
  local f=assert(io.open('tools/rom_manifest_'..e[1]..'.json'));local m=J.decode(f:read('*a'));f:close()
  local x=X.new('',e[1],m);local C=X.BATTLER_COORDS
  T.eq(C.AT,e[2]);T.eq(C.READER,e[3]);T.eq(C.POINTER_AT,0x64)
  local bytes={}
  for r=1,2 do for i,p in ipairs(rows[r])do
    local at=e[2]+(r-1)*16+(i-1)*4
    bytes[at],bytes[at+1],bytes[at+2],bytes[at+3]=p[1],p[2],0,0
  end end
  local pointer=0x08000000+e[2]
  x.rom={u8=function(_,at)return assert(bytes[at],'unexpected coordinate read')end,
    u16=function()error('RS must not read Emerald healthbox instructions')end,
    u32=function(_,at)T.eq(at,e[3]+0x64);return pointer end}
  function x:write(name,value)T.eq(name,'constants');T.eq(value,self._constants)end
  x:extractBattlerCoords()
  local c=x._constants.gen3BattlerCoords
  for r,name in ipairs{'singles','doubles'}do for i,p in ipairs(rows[r])do
    T.eq(c[name][i].x,p[1]);T.eq(c[name][i].y,p[2])
  end end
  T.check(c.doubles[1].x~=c.doubles[3].x and c.doubles[2].x~=c.doubles[4].x,
    'both pairs retain distinct native positions')
  pointer=pointer+4
  T.raises(function()x:extractBattlerCoords()end,'coordinate reader')
  pointer=pointer-4;bytes[e[2]+2]=1;x._constants={}
  x:extractBattlerCoords();T.eq(x._constants.gen3BattlerCoords,nil,'malformed padded row is rejected')
end
X.new('','emerald',{})
T.eq(X.BATTLER_COORDS.AT,0x525f58);T.eq(X.BATTLER_COORDS.READER,0xa5c6c)
T.eq(X.BATTLER_COORDS.POINTER_AT,nil,'RS pointer guard never leaks into another edition')
T.eq(X.BATTLER_COORDS.HEALTHBOX.playerLeft.y,76,'Emerald healthbox instructions restored')
T.finish('RS native battler-position import, reader identity and edition isolation')
