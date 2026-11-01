-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness');local S=require('src.core.SaveSerializer')
local O=require('tests.drivers.hoenn_recovery_oracle')
local scripts={S0000001={{'call',0x08000020},{'goto',0x08000040}},
 S0000020={{'clearflag',123},{'setvar',0x409C,0},{'return'}},
 S0000040={{'compare_var_to_value',0x4096,3},{'goto_if',1,0x08000060},{'end'}},
 S0000060={{'setflag',124},{'end'}}}
local data={constants={gen3RsWhiteout={format=1,version='emerald',entry='S0000001'}},
 map_scripts={scripts=scripts}}
local function fresh(map,scene,briney)
 return{player={map=map,name='TEST'},flags={FLAG_G3_007B=true,UNRELATED=true},
 gen3Vars={[0x409C]=scene,[0x4096]=briney},party={{hp=83}},inventory={REVIVE=1},money=4467}
end
for _,map in ipairs{'MAP_G00_N08','MAP_G16_N10'}do
 for location=0,3 do
  local save=fresh(map,2,location);local before=S.encode(save)
  local expected,changed=O.expected(save,data,'emerald')
  T.eq(changed,true);T.check(expected~=save,'oracle owns a detached snapshot')
  T.eq(expected.flags.FLAG_G3_007B,false,'script-cleared flags retain their explicit stored false');T.eq(expected.gen3Vars[0x409C],0)
  T.eq(expected.flags.FLAG_G3_007C,location==3 and true or nil,'comparison controls original branch')
  T.eq(expected.money,4467);T.eq(expected.party[1].hp,83)
  T.eq(expected.inventory.REVIVE,1);T.eq(expected.flags.UNRELATED,true)
  T.eq(S.encode(save),before,'oracle never edits live/source SAVE')
 end
end
for n=0,9 do
 local save=fresh(('MAP_G16_N%02d'):format(n),2,3)
 local expected,changed=O.expected(save,data,'emerald')
 T.eq(changed,false);T.eq(expected,save,'in-progress room needs no recovery oracle')
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen'}do
 local save=fresh('MAP_G16_N10',2,3)
 local expected,changed=O.expected(save,data,version)
 T.eq(changed,false);T.eq(expected,save)
end
local save=fresh('MAP_G16_N10',0,3)
local expected,changed=O.expected(save,data,'emerald')
T.eq(changed,false);T.eq(expected,save,'idle scene is protected')
save=fresh('MAP_G16_N10',2,3);save.flags.FLAG_G3_007B=nil
expected=O.expected(save,data,'emerald')
T.eq(expected.flags.FLAG_G3_007B,false,'clearing an untouched flag also records explicit false')
T.eq(save.flags.FLAG_G3_007B,nil,'oracle cannot write that marker into source SAVE')
scripts.S0000020[1]={'invented_reset',123}
T.eq(pcall(O.expected,fresh('MAP_G16_N10',2,3),data,'emerald'),false,'unknown bytecode fails the acceptance oracle')
T.finish('Independent imported-bytecode Continue oracle and source SAVE purity')
