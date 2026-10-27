package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local Save=require('src.core.SaveData');local getenv=os.getenv
local isolated=true
os.getenv=function(name)if name=='POKEPORT_ISOLATED_TESTING'then return isolated and '1'or nil end;return getenv(name)end
Save._setOtherLocations({'/qa-test-only-external-profile'})
T.eq(#Save.otherLocations(),0,'explicit isolated testing excludes external recovery roots')
T.eq(#Save._foreignSlots('firered'),0,'isolated title/save checks never discover personal foreign slots')
local extras=Save._slotExtras('firered','slot1');local external=0
for _,row in ipairs(extras)do if row.path then external=external+1 end end
T.eq(external,0,'isolated slot recovery offers no cross-identity file readers')
isolated=false
T.eq(Save.otherLocations()[1],'/qa-test-only-external-profile','ordinary boot retains configured recovery roots')
isolated=true
T.eq(#Save.otherLocations(),0,'cached external roots cannot bypass opt-out')
os.getenv=getenv;Save._setOtherLocations(nil)
T.finish('Explicit QA isolation and foreign-save recovery')
