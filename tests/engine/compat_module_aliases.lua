local T=require('tests.harness')
love=require('tests.love_stub')
local C=require('src.core.ModCompat')
C.install()
T.eq(require('src.world.gen2.WorldAPI'),require('src.world.WorldAPI'),'world API alias preserves object identity')
if loadfile('src/world/OptionalFollower.lua') then
 T.eq(require('src.world.gen2.Follower'),require('src.world.OptionalFollower'),'Gen2 follower alias preserves object identity')
else
 T.raises(function()require('src.world.gen2.Follower')end,'src.world.OptionalFollower','alias identifies an unavailable native follower provider')
end
local names=require('src.mods.Gen1Compat')
for name in pairs(names.UNAVAILABLE)do
 local ok,reason=pcall(require,name)
 T.check(not ok,'unsupported import fails '..name)
 T.check(tostring(reason):find(name,1,true)~=nil,'failure identifies module '..name)
 T.check(tostring(reason):find('mystery_dungeon_follower',1,true)~=nil,'failure identifies affected consumer '..name)
 T.check(not tostring(reason):find('no file ',1,true),'failure does not masquerade as a filesystem search '..name)
end
T.finish()
