-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local Battle=require('src.battle.BattleState')
local helper=require('tests.drivers.story_battle')
for _,initial in ipairs{'menu','moveSelect','messages','targetSelect'}do
 local battler={curMoves={{id='TACKLE',pp=35}}}
 local b=setmetatable({phase=initial,menuIndex=1,moveIndex=1},Battle)
 function b:menuBattler()return battler end
 local top=b;local waits,presses=0,{}
 local game={stack={top=function()return top end}}
 local U={wait=function(n)waits=waits+n end}
 local function press(key,n)
  presses[#presses+1]={key,n}
  if b.phase=='messages'and key=='b'then b.phase='menu'
  elseif b.phase=='menu'and key=='a'then b.phase='moveSelect'
  elseif b.phase=='moveSelect'and key=='a'then b.phase='targetSelect'
  else error('Unexpected ordinary input before pending target selection')end
 end
 local outcome=helper.attack(game,U,press,1)
 T.eq(b.phase,'targetSelect','The battle remains at its actual target picker')
 T.eq(waits,0,'A target picker requires another ordinary input, not 2400 idle frames')
 T.eq(outcome,'ordinary target selection requires input')
 T.eq(battler.curMoves[1].pp,35,'The input helper cannot consume or edit move PP')
 if initial=='targetSelect'then T.eq(#presses,0,'Existing target selection receives no invented confirmation')end
 for _,p in ipairs(presses)do T.check(p[1]~='b'or initial=='messages','Cancel is not used to bypass the target picker')end
end
local b=setmetatable({phase='menu',menuIndex=1,moveIndex=1},Battle)
function b:menuBattler()return{curMoves={{id='TACKLE',pp=35}}}end
local g={stack={top=function()return b end}}
T.eq(helper.attack(g,{wait=function()error('Single battle must not idle here')end},function(key)
 if key=='a'then b.phase=b.phase=='menu'and'moveSelect'or'menu'end
end,1),'turn returned to battle menu','Single-battle menu return stays unchanged')
T.finish('Ordinary double-battle target input handoff')
