-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Cases=dofile('tests/gen3_faint_friendship/cases.lua')
for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
 local rs=edition=='ruby'or edition=='sapphire'
 for _,mode in ipairs({'single','right','right-empty-left'})do
  local rows=Cases.run('.','gen2',edition,mode)
  T.eq(#rows,53,'all native friendship scenarios execute')
  for _,row in ipairs(rows)do
   local events=row.events
   for i,e in ipairs(events)do
    if e.op=='friendship'then
     T.eq(e.reason,'event','native faint owns a friendship event')
     T.check(e.event==7 or e.event==9,'native faint uses its native event byte')
     T.eq(e.to-e.from,e.delta,'public friendship delta is exact')
     T.eq(events[i+1].op,'faint','friendship command precedes its faint notification')
    end
   end
   if row.profile:sub(1,4)=='hit/'and mode=='single'then
    local h,gap=row.profile:match('hit/(%d+)/([%-0-9]+)');h,gap=tonumber(h),tonumber(gap)
    local loss=gap>=30 and(h>=200 and 10 or 5)or 1
    if rs and gap<=0 then loss=0 end
    T.eq(row.happiness,math.max(0,h-loss),'native faint respects edition, level threshold and friendship tier')
   elseif row.profile=='aliases/199/30'then
    T.eq(row.happiness,190,'native friendship alias is authoritative and both aliases are synchronized')
    T.eq(row.alias,190,'happiness follows native friendship after the command')
   elseif row.profile=='hook levels/199/0'then T.eq(row.happiness,194,'script faint reads the reached script levels after the public damage hook')
   elseif row.profile=='egg/199/30'then T.eq(row.happiness,199,'egg guard prevents native friendship loss')end
   T.eq(row.hp,0,'each authored scenario reaches a real native player KO')
  end
 end
end
-- A real native announcement is idempotent even when called twice. A
-- native heal clears logical fainting, but does not invent another active
-- controller or reset its per-announcement friendship command.
local f=dofile('tests/charge_required/fixture.lua').new('.','gen2','firered',3,'unified',false,false,'portable_enemy_action')
local c=f.fresh('TACKLE');local b=c.battle;b:syncSides();c.user.mon.happiness,c.user.mon.friendship=200,200;c.target.mon.level=60
local observed=0
f.e.api.events:on('happiness.changed',function()
 observed=observed+1
 local ok,why=pcall(require('src.core.CheckpointBattle').capture,b.game,b,function(x)return x end)
 T.eq(ok,false,'checkpoint owner rejects the middle of the native friendship command')
 T.check(tostring(why):find('faint announcement is active',1,true)~=nil,'friendship shares the native announcement guard')
end)
b:applyDamage(c.user,1000);b:onFaint(c.user);b:onFaint(c.user)
T.eq(observed,1,'one actual friendship notification is published for the controller')
T.eq(c.user.mon.happiness,190,'duplicate native faint commands spend friendship once')
b:abilityHeal(c.user,1,4);T.eq(c.user._gbaLogicalFaint,nil,'genuine heal retires logical death')
T.eq(c.user._gbaFriendshipFainted,true,'healing does not create a new active controller')
f.close()
local M=require('src.battle.Gen3FaintFriendship')
for _,invalid in ipairs({0,1,'true'})do T.eq(M.valid({}, {_gbaFriendshipFainted=invalid}),false,'native friendship marker requires a boolean')end
for _,invalid in ipairs({-1,256,1.5,'30'})do
 T.eq(M.valid({}, {_gbaFaintContext={other=1,faintedLevel=invalid,otherLevel=30}}),false,'captured native level is a byte')
end
T.eq(M.valid({_gbaFaintRoles={attacker=4,target=1,phase='script'}},{}),false,'native context cannot name a fifth controller')
T.eq(M.valid({_gbaFaintRoles={attacker=0,target=1,phase='unknown'}},{}),false,'native context requires a reached scheduler phase')
T.finish('native faint friendship thresholds, public event order and real action/residual owners')
