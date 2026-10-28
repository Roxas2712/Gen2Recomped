-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.core.Gen3FrlgEndingSave');local S=require('src.core.SaveSerializer')
local function data()return{maps={PALLET={},HOUSE={}},constants={gen3HealLocations={{index=1,outdoor=true,map='PALLET',x=6,y=8,
 respawn={map='HOUSE',x=8,y=5}}}}}end
for _,edition in ipairs{'firered','leafgreen'}do
 for _,gender in ipairs{'boy','girl',0,1,'male','female'}do
  local d=data();local save={version=edition,player={gender=gender,map='HALL',x=5,y=4},specialSaveWarpFlags=0xc0,
   continueGameWarp={map='OLD_WARP',x=99,y=99},party={{species='OWNED',nickname='OWNED NAME'}},hallOfFame=1,gen3Stats={[10]=1}}
  local before=S.encode(save);local writes=0;local durable
  local g={data=d,save=save,writeSave=function(self)
   writes=writes+1;T.eq(self.save.specialSaveWarpFlags,0xc1,'native Hall bit reaches writer once')
   T.same(self.save.continueGameWarp,{map='PALLET',x=6,y=8},'native outdoor Pallet return reaches writer')
   return false
  end}
  T.eq(M.write(g),false,'refusal blocks ending');T.eq(S.encode(save),before,'refusal restores prior fields exactly')
  g.writeSave=function()writes=writes+1;error('OWNED IO FAILURE')end
  T.eq(M.write(g),false,'exception blocks ending');T.eq(S.encode(save),before,'exception restores prior fields exactly')
  g.writeSave=function(self)writes=writes+1;durable=S.decode(S.encode(self.save));return true end
  T.eq(M.write(g),true,'explicit durable success permits ending');T.eq(writes,3,'one authoritative write per attempt')
  T.eq(save.player.map,'HALL','saving does not move live ceremony')
  T.eq(M.apply(durable,d),true,'actual CONTINUE consumes Hall bit')
  T.same(durable.player,{gender=gender,map='PALLET',x=6,y=8,facing='down'},'both genders resume outside in Pallet')
  T.same(durable.lastHeal,{map='HOUSE',x=8,y=5},'whiteout still uses the separate indoor healer')
  T.eq(durable.specialSaveWarpFlags,0xc0,'other native warp bits survive')
  T.eq(M.apply(durable,d),false,'same loaded snapshot cannot relocate twice')
  T.eq(durable.hallOfFame,1,'continue never adds an induction');T.eq(durable.gen3Stats[10],1,'continue never adds a stat')
  T.same(durable.party,save.party,'party identity preserved');T.eq(save.specialSaveWarpFlags,0xc1,'loaded and durable snapshots independent')
 end
 for _,warp in ipairs{{map='FOREIGN',x=6,y=8},{map='PALLET',x=7,y=8},{map='PALLET',x=6,y=9}}do
  local save={version=edition,player={map='HALL'},specialSaveWarpFlags=1,continueGameWarp=warp};local before=S.encode(save)
  T.eq(M.apply(save,data()),false,'foreign warp not spent');T.eq(S.encode(save),before,'foreign snapshot unchanged')
 end
 local save={version=edition,player={map='HALL'},specialSaveWarpFlags=1};local before=S.encode(save)
 T.eq(M.apply(save,data()),false,'bare legacy flag never invents a destination');T.eq(S.encode(save),before,'bare flag preserved')
 for _,change in ipairs{
  function(d)d.constants.gen3HealLocations=nil end,function(d)d.constants.gen3HealLocations[1].index=2 end,
  function(d)d.constants.gen3HealLocations[1].outdoor=false end,function(d)d.maps.PALLET=nil end,
  function(d)d.constants.gen3HealLocations[1].x=-1 end,function(d)d.constants.gen3HealLocations[1].y=8.5 end,
  function(d)d.constants.gen3HealLocations[1].respawn=nil end,function(d)d.maps.HOUSE=nil end,
  function(d)d.constants.gen3HealLocations[1].respawn.x=-1 end}do
  local d=data();change(d);local save={version=edition};local before=S.encode(save)
  T.eq(M.write({data=d,save=save,writeSave=function()error('must not call IO')end}),false,'bad native location rejected before IO')
  T.eq(S.encode(save),before,'bad metadata leaves every saved field alone')
 end
end
for _,edition in ipairs{'ruby','sapphire','emerald','gold','red'}do
 local save={version=edition,player={map='HALL'},specialSaveWarpFlags=1,continueGameWarp={map='PALLET',x=6,y=8}};local before=S.encode(save)
 T.eq(M.apply(save,data()),false,'other edition keeps its return protocol')
 T.eq(M.write({data=data(),save=save}),false,'other edition cannot write FR/LG protocol')
 T.eq(S.encode(save),before,'other edition snapshot unchanged')
end
T.finish('FRLG atomic League save, refusal/retry, outdoor Pallet continue and separate indoor whiteout')
