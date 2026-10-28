package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Battle=require('src.core.game3.battle')
local Seq=require('src.core.game3.battle.anim_seq')
local Plan=require('src.battle.Gen3ActionPlan')
local Probe=dofile('tests/native_action_plan/turn.lua')
local Json=require('src.link.Json')
local base=Seq.begin
local function run(b)
 local row=table.remove(b.queue,1)
 if b.runQueueAction then return b:runQueueAction(row)end
 table.insert(b.queue,1,row);return b:updateQueue()
end
local function prepared(edition)
 local f,b=Probe.open(edition);b:resolveTurn(b.player.mon.moves[1]);return f,b
end
T.eq(base({events={}}),false,'no native action can be invented between phases')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f,b=prepared(edition)
 local before,after,kept,seen,retired,rows
 Seq.begin=function(meta)
  seen=meta.events;rows={};for i,row in ipairs(b.queue)do rows[i]=row end
  before={hp=b.enemy.mon.hp,pp=b.player.mon.moves[1].pp,frame=b.frame}
  local copy={events={}};kept={}
  local used,moves=0,0
  for _,e in ipairs(meta.events)do
   if e.kind=='move'then moves=moves+1;T.eq(e.move,'MOVE_033')
   elseif e.kind=='msg'and Seq.isMoveUsedId(e.id)then used=used+1;T.neq(e.text,nil)
   else copy.events[#copy.events+1]=e;kept[#kept+1]=e end
  end
  T.eq(used,1,'actual native used-message producer is typed once')
  T.eq(moves,1,'actual native animation row is typed once')
  T.raises(function()meta.events[1].kind='move'end,'read-only')
  T.eq(base(copy),true);T.eq(base({events={}}),true,'duplicate base call cannot amend its first request')
  T.same(b.queue,rows,'no filtering commits before decorators finish')
  after={hp=b.enemy.mon.hp,pp=b.player.mon.moves[1].pp,frame=b.frame}
  retired=meta.events[1]
 end
 run(b)
 T.same(before,after,'presentation filtering cannot resolve damage, PP or frames')
 local remaining={};for _,row in ipairs(b.queue)do remaining[row]=true end
 for _,row in ipairs(rows)do
  local removed=not remaining[row]
  if removed then T.eq(row.fn,nil);T.eq(row.ui,nil);T.eq(row.drain,nil);T.eq(row.exp,nil)end
 end
 T.eq(#rows-#b.queue,2,'only native move animation and used-message rows are removed')
 T.eq(retired.kind,nil,'events cannot retain an expired native action admission')
 T.same(require('src.compat.gen1.TableIteration').snapshot(retired),{})
 T.eq(base({events=seen}),false,'retained events cannot request another presentation')
 Seq.begin=base;Probe.close(f)
end

-- Real complete native turns compare observation-only/no-op sequence behavior.
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 package.loaded['src.core.game3.battle.anim_seq']=nil
 local expected=Probe.turn(edition,true)
 package.loaded['src.core.game3.battle.anim_seq']=Seq
 Seq.begin=base;T.same(Probe.turn(edition,true),expected,'default sequence preserves native full-turn HP/PP/RNG/frame trace')
 Seq.begin=function(meta)return base(meta)end
 T.same(Probe.turn(edition,true),expected,'no-op sequence decorator preserves native full-turn HP/PP/RNG/frame trace')
 Seq.begin=base
end

for _,mode in ipairs{'foreign','reorder','duplicate','mandatory','throw-before','throw-after','row-change','covered','save-change'}do
 local f,b=prepared('emerald');local original,events
 Seq.begin=function(meta)
  original={};for i,row in ipairs(b.queue)do original[i]=row end;events=meta.events
  if mode=='foreign'then return base({events={{kind='move'}}})
  elseif mode=='reorder'then local a={};for i=#meta.events,1,-1 do a[#a+1]=meta.events[i]end;return base({events=a})
  elseif mode=='duplicate'then return base({events={meta.events[1],meta.events[1]}})
  elseif mode=='mandatory'then return base({events={}})
  elseif mode=='throw-before'then error('before animation request')
  elseif mode=='throw-after'then base(meta);error('after animation request')
  elseif mode=='row-change'then b.queue[1].fn=function()end;return base(meta)
  elseif mode=='covered'then f.game.stack:push({});return base(meta)
  elseif mode=='save-change'then f.game.save={};return base(meta)end
 end
 local ok=pcall(run,b);T.eq(ok,false,mode..' rejects invalid presentation admission')
 T.same(b.queue,original,mode..' cannot delete native queue rows')
 T.eq(events[1].kind,nil,mode..' retires retained event permissions')
 T.eq(b._sourceActionPlan,nil,mode..' cannot leave an executing action observation')
 Seq.begin=base;Probe.close(f)
end

-- Rows carrying another native protocol keep their place even if tagged.
do
 local f,b=prepared('emerald');local observed
 Seq.begin=function(meta)
  observed=meta.events
  for _,event in ipairs(meta.events)do T.eq(event.kind,'native','foreign gameplay payload cannot become a removable move')end
  return base(meta)
 end
 local row={anim='MOVE_033',fn=function()end};Seq._nativeMove(row)
 local count=0;Seq._nativeAction(b,{},function()count=count+1;table.insert(b.queue,1,row)end)
 T.eq(count,1);T.eq(b.queue[1],row);T.eq(observed[1].kind,nil)
 Seq.begin=base;Probe.close(f)
end
-- Localization/lookalike text does not grant native announcement provenance.
do
 local f,b=prepared('emerald');local observed
 Seq.begin=function(meta)
  observed=meta.events;T.eq(meta.events[1].kind,'native')
  T.raises(function()base({events={}})end,'cannot be removed')
  return base(meta)
 end
 local text='CHARMANDER\nused TACKLE!'
 Seq._nativeAction(b,{},function()b:sayNext(text)end)
 T.eq(b.queue[1].text,text);T.eq(observed[1].kind,nil)
 Seq.begin=base;Probe.close(f)
end
-- Callback attribution is restored; native failures never replay a move.
do
 local f,b=prepared('emerald');local G=require('src.core.Game3')
 local seams=require('src.mods.ModSeams');local owner=G._callbackOwner()
 Seq.begin=function(meta)T.eq(G._callbackOwner(),'animation_owner');return base(meta)end
 seams._journal[#seams._journal+1]={tbl=Seq,key='begin',after=Seq.begin,owner='animation_owner'}
 run(b);T.eq(G._callbackOwner(),owner);table.remove(seams._journal)
 local calls=0
 T.raises(function()Seq._nativeAction(b,{},function()calls=calls+1;error('native action failure')end)end,'native action failure')
 T.eq(calls,1);T.eq(G._callbackOwner(),owner)
 Seq.begin=base;Probe.close(f)
end
-- Another generation keeps its direct action call and never borrows this API.
do
 require('src.core.GameVersion').set('gold')
 local called,decorated=0,0
 Seq.begin=function()decorated=decorated+1 end
 Plan.run({}, {fn=function()called=called+1 end})
 T.eq(called,1);T.eq(decorated,0)
 Seq.begin=base
end
T.eq(Plan.cursor(nil),0)
T.finish('Actual native animation row provenance, restricted presentation filtering and default combat invariance')
