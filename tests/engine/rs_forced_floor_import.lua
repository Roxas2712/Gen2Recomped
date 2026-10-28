-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local J=require('src.link.Json')
local native={ruby={0x58944,0x30fb58,0x30fba0,0x589ec,0x58b6c},
  sapphire={0x58948,0x30fae8,0x30fb30,0x589f0,0x58b70}}
local behaviours={72,32,67,66,65,64,83,82,81,80,71,70,69,68,19,187,188,208}
local ways={'down','up','left','right'}
for _,edition in ipairs{'ruby','sapphire'}do
  local f=assert(io.open('tools/rom_manifest_'..edition..'.json'));local m=J.decode(f:read('*a'));f:close()
  local x=X.new('',edition,m);local F=X.FORCED_MOVEMENT;local a=native[edition]
  T.same({F.DISPATCH,F.TESTS,F.FUNCS,F.WALK_DRIVER,F.SLIDE_DRIVER},a,'edition owns its code and table anchors')
  local half,word,calls,reads={},{},{},{}
  half[a[1]+F.AT_COUNT]=0x2c11 -- the native loop's last index, not a fabricated row count
  for i,b in ipairs(behaviours)do
    local pred,action=0x1000+i*64,0x3000+i*32
    word[a[2]+(i-1)*4]=0x08000001+pred
    word[a[3]+i*4]=0x08000001+action -- action zero is the NONE entry
    half[pred],half[pred+2],half[pred+4],half[pred+6]=0x0600,0x0e00,0x2800+b,0x4700
    local direction=(i-3)%4+1
    half[action],half[action+2],half[action+4]=0xb500,0x4904,0x2000+direction
    calls[action]=(i>=11 and i<=14)and a[5]or(i>=3 and i<=15)and a[4]or 0
  end
  x.rom={u16=function(_,at)reads[at]=true;return half[at]or 0 end,
    u32=function(_,at)reads[at]=true;return word[at]or 0 end}
  function x:blTargets(at)return{calls[at]or 0}end
  local pairs_={first={collision={}},second={collision={}}}
  local rows,keys=x:forcedMovementBehaviours(pairs_)
  T.eq(#keys,13,'eight floors, four currents and waterfall; special mat actions are excluded')
  T.check(reads[a[1]+0x4e]and reads[a[2]]and reads[a[3]+18*4],'loop and both table boundaries read')
  T.check(X.forcedFloorRulesReady(rows),'both full floor families required')
  for i,way in ipairs(ways)do
    T.eq(rows[0x44-i].way,way);T.eq(rows[0x44-i].slide,nil)
    T.eq(rows[0x48-i].way,way);T.eq(rows[0x48-i].slide,true)
  end
  T.eq(pairs_.first.forcedMovement,rows);T.eq(pairs_.second.forcedMovement,rows)
  T.eq(x._constants.gen3ForcedMovement,rows)
  local saved=rows[0x40];rows[0x40]=nil;T.eq(X.forcedFloorRulesReady(rows),false,'missing arrow cannot qualify')
  rows[0x40]={way='left'};T.eq(X.forcedFloorRulesReady(rows),false,'reversed direction cannot qualify')
  rows[0x40]={way='right',slide=true};T.eq(X.forcedFloorRulesReady(rows),false,'walking floor cannot become a slide')
  rows[0x40]=saved;T.eq(X.forcedFloorRulesReady(rows),true)
  -- A predicate with two comparisons or an unrelated driver is never guessed.
  half[0x1000+3*64+6]=0x2844;half[0x1000+3*64+8]=0x4700
  local damaged=x:forcedMovementBehaviours({});T.eq(damaged[0x43],nil)
  T.eq(X.forcedFloorRulesReady(damaged),false)
  half[a[1]+F.AT_COUNT]=0;T.eq(x:forcedMovementBehaviours({}),nil,'wrong code bound records nothing')
end
T.eq(X.forcedFloorRulesReady(nil),false)
X.new('','emerald',{})
T.eq(X.FORCED_MOVEMENT.DISPATCH,0x08ab38,'later Emerald import restores its own code anchors')
T.eq(X.FORCED_MOVEMENT.TESTS,0x4973fc)
T.finish('RS native forced floors, malformed code rejection and cross-edition stage restoration')
