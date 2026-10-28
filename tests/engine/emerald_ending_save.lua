-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.core.Gen3EmeraldEndingSave')
local S=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
local data={maps={BOY={},GIRL={}},constants={gen3PlayerRoom={boy='BOY',girl='GIRL',x=4,y=2}}}
for _,gender in ipairs{'boy','girl',0,1,'male','female'}do
  local female=gender=='girl'or gender=='female'or gender==1
  local save={version='emerald',player={gender=gender,map='HALL',x=8,y=4},specialSaveWarpFlags=0x41,
    party={{species='TREECKO',level=50}},hallOfFame=1,gen3Stats={[10]=1}}
  local before=S.encode(save);local writes=0
  local game={data=data,save=save,writeSave=function(g)
    writes=writes+1;T.eq(g.save.specialSaveWarpFlags,0xc1,'original Emerald bit reaches writer');return false
  end}
  T.eq(M.write(game),false,'refusal blocks native ending');T.eq(S.encode(save),before,'refusal restores helper fields')
  game.writeSave=function()writes=writes+1;error('IO failure')end
  T.eq(M.write(game),false,'exception blocks native ending');T.eq(S.encode(save),before,'exception restores helper fields')
  local durable;game.writeSave=function(g)writes=writes+1;durable=S.decode(S.encode(g.save));return true end
  T.eq(M.write(game),true,'explicit durable success permits ending');T.eq(writes,3,'one writer per attempt')
  T.eq(save.player.map,'HALL','autosave does not warp the live ceremony')
  T.eq(M.apply(durable,data),true,'CONTINUE consumes original Emerald bit')
  T.eq(durable.player.map,female and'GIRL'or'BOY','ROM gender bedroom selected')
  T.eq(durable.player.x,4);T.eq(durable.player.y,2);T.eq(durable.player.facing,'down')
  T.eq(durable.specialSaveWarpFlags,0x41,'unrelated bits including RS bit survive')
  T.eq(durable.hallOfFame,1,'no second induction');T.eq(durable.gen3Stats[10],1,'no second game stat')
  T.same(durable.party,save.party,'stable host party unchanged');T.eq(M.apply(durable,data),false,'one-shot return')
  T.eq(save.specialSaveWarpFlags,0xc1,'loading does not change the durable snapshot')
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold','red'}do
  local save={version=version,player={map='HALL'},specialSaveWarpFlags=0x81};local before=S.encode(save)
  T.eq(M.apply(save,data),false,'other version keeps its existing return flow')
  T.eq(M.write({data=data,save=save}),false,'other version cannot enter Emerald writer')
  T.eq(S.encode(save),before,'other version unchanged')
end
local old={version='emerald',player={gender='girl',map='HALL'},specialSaveWarpFlags=0x80}
T.eq(M.apply(old,data),true,'existing Emerald champion bit resumes in its original bedroom')
T.eq(old.player.map,'GIRL','old Emerald saves also use the correct gender')
local unknown={version='emerald',player={map='HALL'},specialSaveWarpFlags=0x80};local before=S.encode(unknown)
T.eq(M.apply(unknown,{maps={},constants={}}),false,'missing metadata retains existing fallback')
T.eq(S.encode(unknown),before,'fallback bit remains available to legacy loader')
T.eq(M.write({data={maps={},constants={}},save=unknown,writeSave=function()error('must not write')end}),false,'missing room fails before IO')
for _,value in ipairs{0,1,'ok'}do
  local save={version='emerald',player={},specialSaveWarpFlags=0};local before=S.encode(save)
  T.eq(M.write({data=data,save=save,writeSave=function()return value end}),false,'truthy non-success is refused')
  T.eq(S.encode(save),before,'non-success restores flags')
end
T.finish('Emerald atomic League save retry, native bit, ROM gender home and one-shot CONTINUE')
