package.path='./?.lua;./?/init.lua;'..package.path
local B=require('src.features.gen1_gsc.Bundle')
local T=require('tests.harness')
local original=math.random
for _,name in ipairs{'g3u_table_test','g3u_wire_test','g3u_scope_test','g3u_mechanics_test','g3u_lockstep_test'}do
 local b=B.new{profile='g3u',testing=true,testLabel=name}
 b:require('tests.engine.'..name)
 T.eq(math.random,original,'source isolation cannot replace the host random stream')
end
T.finish('Pinned cross-engine shared battle kernel')
