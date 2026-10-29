-- Dump actual public owners in each engine; CI compares every GSC class.
package.path='./?.lua;./?/init.lua;'..package.path
local P=require(arg[1]=='reference' and 'src.world.gen2.Permissions' or 'src.world.Collision')
for byte=0,511 do
 io.write(byte,':',P.of(byte),':',tostring(P.isWater(byte)),':',tostring(P.isLand(byte)),
  ':',tostring(P.isWall(byte)),':',tostring(P.isWalkable(byte)),':',tostring(P.isLedge(byte)),
  ':',P.surfable(byte)or'-','\n')
end
