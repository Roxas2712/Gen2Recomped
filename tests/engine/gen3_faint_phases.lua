-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Cases=dofile('tests/gen3_faint_phases/cases.lua')
for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
  for _,mode in ipairs({'single','right','right-empty-left'})do
    local rows=Cases.run('.','gen2',edition,mode)
    T.eq(#rows,62,'all native faint/reactive profiles execute')
    local uid=mode=='single'and 0 or 2
    for _,row in ipairs(rows)do
      local faints={}
      for _,e in ipairs(row.events)do
        if e.op=='faint'then
          faints[#faints+1]=e.id
          T.eq(e.status,false,'status is clear before the public faint callback')
        end
      end
      if row.profile=='normal' or row.profile=='all targets faint' or row.profile=='Metronome Explosion' then
        T.eq(faints[#faints],uid,'the native user announcement follows every reached target')
        local count=0;for _,id in ipairs(faints)do if id==uid then count=count+1 end end
        T.eq(count,1,'self KO is announced once across spread/called bodies')
      elseif row.profile=='damage hook heals' or row.profile=='Metronome heal' then
        T.eq(row.after[uid+1].hp,0,'a raw HP write cannot erase the native logical faint')
      elseif row.profile=='Shell Bell heals' then
        T.eq(row.after[uid+1].hp>0,mode~='single','a real native Shell Bell heal clears logical faint only before the deferred spread announcement')
      elseif row.profile=='fixed Grudge' or row.profile=='Nature Power Grudge' then
        T.eq(row.after[uid+1].pp,0,'Grudge drains the selected native slot')
        for _,e in ipairs(row.events)do if e.op=='faint'and e.id~=uid then T.eq(e.user.pp,39,'target callback precedes the Grudge PP command')end end
      elseif row.profile=='fixed both' or row.profile=='Nature Power both' then
        T.eq(row.after[uid+1].pp,39,'Destiny Bond resolves before Grudge can spend a fainted user PP')
        T.eq(row.after[uid+1].hp,0,'the opposing attacker follows Destiny Bond')
      elseif row.profile=='fixed called Grudge' then
        T.eq(row.after[uid+1].pp,40,'an unowned called move has no selected PP slot to drain')
      elseif (row.profile=='fixed ally Bond'or row.profile=='Nature Power ally Bond') and mode~='single' then
        T.eq(row.after[uid+1].hp,400,'a same-side target cannot take its ally with Destiny Bond')
      elseif row.profile=='target status' then
        for _,actor in ipairs(row.after)do
          if actor then T.eq(actor.status,false,'native faint removes major status');T.eq(actor.toxic,false,'toxic counter retires');T.eq(actor.sleep,false,'sleep counter retires')end
        end
      end
    end
  end
end
-- An uncaught native failure must release frame owners. Its already executed
-- HP command remains real; a subsequent raw HP write is not a native heal.
local Fixture=dofile('tests/charge_required/fixture.lua')
local f=Fixture.new('.','gen2','firered',3,'unified',false,false,'portable_enemy_action',function(data)
  data.moves.EXP={id='EXP',index=153,name='EXPLOSION',gen3Effect=7,effect='EXPLODE_EFFECT',
    power=200,type='NORMAL',accuracy=100,pp=40,target=0,flags=51}
end)
local c=f.fresh('TACKLE');local b=c.battle;b:syncSides()
c.user.curMoves={{id='EXP',pp=40}};c.user.mon.moves=c.user.curMoves
local compute=b.computeDamage
b.computeDamage=function()error('native-faint-owner-probe')end
local ok,err=pcall(b.executeAction,b,c.user,c.target,c.user.curMoves[1])
T.check(not ok and tostring(err):find('native-faint-owner-probe',1,true),'native error propagates')
for _,key in ipairs({'_gbaMoveFrame','_gbaActionFrame','_gbaNextCaller','_gbaFaintRelease','_gbaFaintAnnouncement','_gbaDamageCalculation'})do T.eq(b[key],nil,'native error retires '..key)end
T.eq(c.user.mon.hp,0,'native error preserves the actual executed HP command')
b.computeDamage=compute
c.user.mon.hp=10
b:executeAction(c.user,c.target,c.user.curMoves[1])
T.eq(c.user.mon.hp,10,'raw HP cannot restart a logically fainted native actor')
b:abilityHeal(c.user,1,4)
T.eq(c.user._gbaLogicalFaint,nil,'genuine native healing clears the logical faint')
f.close()
T.finish('native Explosion target/user phases, status, PP reactions and real healing ownership')
