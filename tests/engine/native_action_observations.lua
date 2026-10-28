package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local B=require('src.core.game3.battle')
local Plan=require('src.battle.Gen3ActionPlan')
local Json=require('src.link.Json')
local Version=require('src.core.GameVersion')
local Probe=dofile('tests/native_action_plan/turn.lua')
local open,close=Probe.open,Probe.close
local function runNativeAction(b,row)
 if b.runQueueAction then return b:runQueueAction(row)end
 -- Earlier native owners invoke the same row in updateQueue itself.
 table.insert(b.queue,1,row)
 return b:updateQueue()
end
T.eq(B._actions,nil,'there is no invented action owner before battle admission')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f,b=open(edition)
 local rolls={};b.rng=function(lo,hi)rolls[#rolls+1]={lo,hi};return lo or 0 end
 b:resolveTurn(b.player.mon.moves[1])
 local native=b._sourceActionPlan
 local actions=assert(B._actions)
 T.eq(#actions,#native.order,'observations follow the actual native turn order')
 T.eq(#actions,2,'ordinary singles observe two actual action rows')
 local first=actions[1]
 T.eq(B._actions[1],first,'repeated queries retain action identity')
 T.eq(first.kind,'move');T.eq(first.meta,false)
 T.eq(first.move,'MOVE_033')
 T.eq(require('src.core.game3.battle.moves').get(first.move).numId,33,'move identity uses the native imported catalog')
 T.eq(first.user,native.order[1][1]==b.player and'player'or'enemy')
 T.eq(first.target,native.order[1][2]==b.player and'player'or'enemy')
 T.eq(first.order,1);T.eq(B._actionI,1,'cursor identifies the real first queue row')
 T.eq(native.rows[1],b.queue[1],'observation records reference the actual queued native fn')
 T.eq(B._phase,b.phase,'observations do not advertise an unimplemented action phase')
 local save=Json.encode(f.game.save);local frame,rollCount,queue=b.frame,#rolls,{}
 for i,row in ipairs(b.queue)do queue[i]=row end
 for _=1,40 do
  T.eq(B._actionI,1);T.eq(B._actions[1],first);T.eq(first.move,'MOVE_033')
 end
 T.eq(Json.encode(f.game.save),save,'action queries do not write saves or party data')
 T.eq(b.frame,frame,'action queries do not tick a battle')
 T.eq(#rolls,rollCount,'action queries do not consume RNG')
 T.same(b.queue,queue,'action queries preserve every native queue row')
 actions[1]=nil
 T.eq(B._actions[1],first,'mutating a detached order array cannot change native planning')
 T.raises(function()first.move='OTHER'end,'read-only')
 local row=table.remove(b.queue,1)
 local Runtime=require('src.mods.Runtime');local emit=Runtime.emit;local observed=false
 Runtime.emit=function(name,payload,...)
  if name=='battle.move_used'and payload.battle==b then
   observed=true
   T.eq(B._actionI,1,'a removed but executing native fn still owns its action cursor')
   T.eq(B._actions[1],first)
  end
  return emit(name,payload,...)
 end
 local ran,why=pcall(runNativeAction,b,row);Runtime.emit=emit;assert(ran,why)
 T.eq(observed,true,'cursor is observed at the real native move-used producer')
 T.eq(B._actionI,0,'presentation rows are not reported as an executing action')
 local nextAction=native.rows[2]
 table.insert(b.queue,1,{text='owned presentation row'})
 T.eq(B._actionI,0,'an unrelated presentation row cannot invent action readiness')
 b.queue={nextAction};T.eq(first.kind,nil,'replacing the native queue retires old observations')
 b.queue=queue;T.eq(first.kind,nil,'restoring a queue cannot revive its retired observation')
 close(f)
 T.eq(first.kind,nil,'an exited native battle cannot retain action access')
end

-- Compare complete native turns with and without observer registration.
-- Actual HP, PP, every RNG call, frame count and phase sequence must agree.
local plain,observed=Probe.turn('firered',false),Probe.turn('firered',true)
if Json.encode(plain)~=Json.encode(observed)then
 print('ACTION_TURN_LENGTHS',#plain.trace,#observed.trace,#plain.rolls,#observed.rolls)
 for i=1,math.max(#plain.trace,#observed.trace)do
  if Json.encode(plain.trace[i])~=Json.encode(observed.trace[i])then
   print('FIRST_NATIVE_TURN_DIFFERENCE',i,Json.encode(plain.trace[i]),Json.encode(observed.trace[i]));break
  end
 end
 for i=1,math.max(#plain.rolls,#observed.rolls)do
  if Json.encode(plain.rolls[i])~=Json.encode(observed.rolls[i])then
   print('FIRST_NATIVE_RNG_DIFFERENCE',i,Json.encode(plain.rolls[i]),Json.encode(observed.rolls[i]));break
  end
 end
end
T.same(plain,observed,'observation registration preserves complete native HP/PP/RNG/order/frame behavior')
for _,edition in ipairs{'leafgreen','ruby','sapphire','emerald'}do
 T.same(Probe.turn(edition,false),Probe.turn(edition,true),edition..' preserves complete native HP/PP/RNG/order/frame behavior')
end

for _,key in ipairs{'data','save','mods','stack','edition'}do
 local f,b=open('emerald');b:resolveTurn(b.player.mon.moves[1]);local view=B._actions[1]
 local old
 if key=='edition'then old=Version.get();Version.set('firered')
 else old=f.game[key];f.game[key]={}end
 T.eq(view.kind,nil,key..' replacement retires action observations')
 if key=='edition'then Version.set(old)else f.game[key]=old end
 T.eq(view.kind,nil,key..' restoration cannot resurrect the old action owner')
 close(f)
end
do
 local f,b=open('emerald');f.game.mods=nil
 b:resolveTurn(b.player.mon.moves[1]);local view=B._actions[1]
 f.game.mods=false
 T.eq(view.kind,nil,'an absent loader and a false loader are distinct cohorts')
 f.game.mods=nil
 T.eq(view.kind,nil,'an absent loader cannot revive the previous cohort')
 close(f)
end
do
 local f,b=open('emerald');b:resolveTurn(b.player.mon.moves[1]);local old=B._actions[1]
 B._service.release()
 T.eq(old.kind,nil,'source admission retirement invalidates the old action record')
 T.neq(B._actions[1],old,'a new source admission owns fresh action views')
 local row=table.remove(b.queue,1);local calls=0
 row.fn=function()calls=calls+1;error('owned native action failure')end
 T.raises(function()runNativeAction(b,row)end,'owned native action failure')
 T.eq(calls,1);T.eq(B._actions,nil,'a failed native action leaves no executing observation')
 close(f)
end
do
 local f,b=open('firered');b:resolveTurn(b.player.mon.moves[1]);local view=B._actions[1]
 local row=b.queue[1];local fn=row.fn
 row.fn=function()end
 T.eq(view.kind,nil,'replacing a pending native callback retires its provenance')
 row.fn=fn
 T.eq(view.kind,nil,'restoring a callback cannot revive its retired provenance')
 close(f)
end
do
 local f,b=open('firered');local act=b.act
 b.act=function(self,fn)act(self,function()return fn()end)end
 b:resolveTurn(b.player.mon.moves[1])
 T.eq(#b.queue,3,'a native act wrapper retains both action rows and end-of-turn')
 T.eq(B._actions,nil,'a replaced native callback cannot be mislabelled as a verified action')
 T.eq(B._actionI,0,'unknown callback provenance cannot invent an action cursor')
 close(f)
end
Version.set('gold')
local sentinel={};local other={_sourceActionPlan=sentinel}
T.eq(Plan.begin(other,{}),nil,'Gen2 never constructs a GBA action ledger')
T.eq(other._sourceActionPlan,sentinel,'Gen2 native state remains untouched')
T.eq(package.loaded['src.core.game3.battle.engine'],nil,'read-only facts do not install a resolver stub')
T.eq(package.loaded['src.core.game3.battle.anim_seq'],nil,'read-only facts do not install a sequence stub')
T.finish('Native action order, queue identity, pure observations and unchanged default turn execution')
