-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Accuracy=require('src.battle.Gen3Accuracy')
local Copy=require('src.mods.Merge').deepCopy
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=dofile('tests/enemy_actions/fixture.lua').new('.','gen2',version,3,'unified')
 for _,enemy in ipairs{false,true}do
  local c=f.fresh('TACKLE',{enemy=enemy});local b=c.battle
  local move=Copy(f.data.moves[f.ids.TACKLE]);move.accuracy=83
  local count,roll=0,83
  b.rng=function(lo,hi)T.eq(lo,1);T.eq(hi,100);count=count+1;return roll end
  for _,value in ipairs{82,83,84,100}do
   roll=value
   local before=count;local ordinary=Accuracy.check(b,move,c.user,c.target,nil)
   T.eq(count,before+1,'absent override draws once')
   before=count;local absent=Accuracy.check(b,move,c.user,c.target,false)
   T.eq(absent,ordinary,'false dispatcher sentinel preserves the ordinary threshold')
   T.eq(count,before+1,'false does not skip or add an accuracy draw')
  end
  roll=1;T.eq(Accuracy.check(b,move,c.user,c.target,0),false,'numeric zero is a real miss threshold')
  roll=100;T.eq(Accuracy.check(b,move,c.user,c.target,255),true,'numeric full threshold remains valid')
  roll=50;T.eq(Accuracy.check(b,move,c.user,c.target,128),true)
  roll=51;T.eq(Accuracy.check(b,move,c.user,c.target,128),false)
  -- Reproduce the actual ordinary damaging dispatcher, whose missing record
  -- is false rather than nil when the merged effect registry exists.
  local actual=f.data.moves[f.ids.TACKLE];local old=actual.effect
  actual.effect='QA_ABSENT_ACCURACY_RECORD'
  T.eq(b:effectRecord(actual.effect),false,'exercise the real missing-record producer')
  b.rng=function(lo)return lo end
  local hp,pp=c.hp(),c.pp();c.use()
  T.check(c.hp()<hp,'ordinary damage reaches the real target without crashing')
  T.eq(c.pp(),pp-1,'the ordinary turn spends exactly one PP')
  actual.effect=old
 end
 f.close()
end
T.finish('all five GBA editions preserve absent accuracy overrides through real damaging moves')
