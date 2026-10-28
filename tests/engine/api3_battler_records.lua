package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
local Records = require('src.mods.CallbackRecords')
local Fixture = require('tests.charge_required.fixture')
local Copy = require('src.mods.Merge').deepCopy
local root = '.'
for _, edition in ipairs({'red','gold','firered','leafgreen','emerald','ruby','sapphire','platinum','black'}) do
  local f = Fixture.new(root,'gen2',edition,3,'unified',false,false,'portable_enemy_action',nil,
    function(files) files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end' end)
  local c=f.fresh('TACKLE'); c.battle:syncSides()
  local actor,mon=c.user,c.user.mon
  mon.status='BRN'
  local function boundary(api)
    local b=Records.new(f.result.loader,'battle.damage',f.gen,api~=false)
    -- An earlier mon view must not make later flattened edits disappear.
    local p=b.view(mon,'mon');local v=b.view(actor,'battler')
    return b,p,v
  end
  local b,p,v=boundary()
  local other=b.view(actor,'battler')
  T.neq(other,v,'API3 battler wrappers retain independent call-local snapshots')
  T.eq(other.mon,p,'independent battler wrappers share the bound Pokemon')
  T.eq(v.mon,p,edition..' bound mon identity')
  for _,key in ipairs({'species','item','nickname','name','level','hp','maxHp','status','isEgg','stats','moves','dvs','shiny'}) do
    T.eq(v[key],p[key],edition..' flattened '..key)
  end
  T.eq(v.stats,p.stats,'stats share their public identity')
  T.eq(v.moves,p.moves,'moves share their public identity')
  if f.gen==3 then T.eq(v.id,0,'real GBA position is the public ID') end
  if f.gen==2 then T.eq(v.side,nil,'Gen2 reference metadata comes from the underlying Pokemon') end
  local rawStats,rawMoves=mon.stats,mon.moves
  v.hp=350;v.stats.attack=100;v.status=nil
  b.commit()
  T.eq(mon.hp,350,'flat HP reaches native mon even when mon was bound first')
  T.eq(mon.stats.attack,100,'flat stat reaches the actual native stats')
  T.eq(mon.status,nil,'flat nil clears native status')
  T.eq(mon.stats,rawStats,'native stats identity retained')
  T.eq(mon.moves,rawMoves,'native move-list identity retained')
  mon.hp=330
  b.refresh('next')
  T.eq(v.hp,350,'API3 retains the caller snapshot across next')
  T.eq(p.hp,350,'nested snapshot is retained too')
  b.commit();T.eq(mon.hp,330,'unchanged snapshots do not overwrite downstream changes')
  p.hp=320;b.commit();T.eq(mon.hp,320,'nested edits after next remain writable')
  v.hp=310;p.hp=300;b.commit();T.eq(mon.hp,310,'changed flat HP wins over conflicting nested HP')
  local oldStats=v.stats
  p.stats=Copy(p.stats);p.stats.attack=90;oldStats.attack=110
  b.commit();T.eq(mon.stats.attack,90,'a detached old flat table does not replace the nested record')
  mon.hp=250;b.refresh()
  T.eq(p.hp,250,'native helper refreshes its bound mon')
  T.eq(v.hp,310,'native helper retains flattened scalar snapshot')
  b.commit();T.eq(mon.hp,250,'helper changes survive the final commit')
  b.close()
  mon.nickname,mon.name=nil,nil
  local names,np,nv=boundary()
  T.eq(np.name,'CHARMANDER','unnamed native Pokemon use their catalogue name')
  T.eq(nv.name,np.name,'flattened name retains the same fallback')
  local slot=mon.moves[1]
  nv.moves[1].pp=3;names.commit()
  T.eq(mon.moves[1].pp,3,'flat PP edits reach the native slot')
  T.eq(mon.moves[1],slot,'flat PP edits preserve the native slot identity')
  T.eq(actor.curMoves[1],slot,'active battle move aliases retain that slot')
  names.close()
  for _,bad in ipairs({'stat','metadata','name','identity','unknown'}) do
    local tx,pm,pb=boundary();local before=Copy(mon)
    pb.hp=200
    if bad=='stat' then pb.stats.attack=-1
    elseif bad=='metadata' then pb.id=99
    elseif bad=='name' then pb.name='FORGED'
    elseif bad=='identity' then pb.mon=Copy(pm)
    else pb.unclassified=true end
    T.raises(function()tx.commit()end,nil,'invalid '..bad..' rejects the whole transaction')
    T.same(mon,before,'invalid flat edits never partially mutate native state')
    tx.close()
  end
  local legacy,lp,lv=boundary(false)
  T.eq(lv.hp,nil,'API2 keeps its existing nested-only record')
  mon.hp=240;legacy.refresh('next')
  T.eq(lp.hp,240,'API2 keeps downstream refresh semantics')
  legacy.close()
  f.close()
end
T.finish('portable API3 battler aliases, snapshots and atomic native writes')
