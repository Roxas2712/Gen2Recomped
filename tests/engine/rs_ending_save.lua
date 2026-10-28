-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.core.Gen3RsEndingSave')
local S=require('src.core.SaveSerializer')
local data={maps={BOY={},GIRL={}},constants={gen3PlayerRoom={boy='BOY',girl='GIRL',x=4,y=2}}}
for _,version in ipairs{'ruby','sapphire'}do
  for _,gender in ipairs{'boy','girl',0,1,'male','female'}do
    local female=gender=='girl'or gender=='female'or gender==1
    local save={version=version,player={gender=gender,map='HALL',x=8,y=4},specialSaveWarpFlags=0x40,
      party={{species='TREECKO',level=50}},hallOfFame=1,gen3Stats={[10]=1}}
    local before=S.encode(save);local writes=0
    local game={data=data,save=save,writeSave=function(g)
      writes=writes+1
      T.eq(g.save.specialSaveWarpFlags,0x41,'native RS bit reaches atomic writer')
      T.eq(g.save.gen3RsEndingReturn.map,female and'GIRL'or'BOY','correct ROM bedroom reaches disk')
      return false
    end}
    T.eq(M.write(game),false,'refusal blocks ending')
    T.eq(S.encode(save),before,'refusal restores helper-owned fields exactly')
    game.writeSave=function()writes=writes+1;error('IO failure')end
    T.eq(M.write(game),false,'exception blocks ending')
    T.eq(S.encode(save),before,'exception restores helper-owned fields exactly')
    local durable
    game.writeSave=function(g)writes=writes+1;durable=S.decode(S.encode(g.save));return true end
    T.eq(M.write(game),true,'explicit durable success permits ending')
    T.eq(writes,3,'one writer call for each explicit attempt')
    T.eq(save.player.map,'HALL','saving does not warp live ceremony')
    T.eq(M.apply(durable,data),true,'continue consumes original RS return bit')
    T.eq(durable.player.map,female and'GIRL'or'BOY','continue uses correct bedroom')
    T.eq(durable.player.x,4,'native home x');T.eq(durable.player.y,2,'native home y')
    T.eq(durable.player.facing,'down','home facing')
    T.eq(durable.specialSaveWarpFlags,0x40,'unrelated warp bits survive')
    T.eq(durable.gen3RsEndingReturn,nil,'one-shot marker consumed in RAM')
    T.eq(M.apply(durable,data),false,'same loaded save cannot warp twice')
    T.eq(durable.hallOfFame,1,'loading never adds another induction')
    T.eq(durable.gen3Stats[10],1,'loading never counts a second induction')
    T.same(durable.party,save.party,'home return leaves party unchanged')
    T.eq(save.specialSaveWarpFlags,0x41,'disk snapshot and live return flags do not alias')
  end
  for _,tag in ipairs{{format=9,version=version,map='BOY',x=4,y=2},
    {format=1,version=version,map='TRUCK',x=4,y=2},
    {format=1,version='emerald',map='BOY',x=4,y=2},
    {format=1,version=version,map='BOY',x=99,y=2}}do
    local save={version=version,player={gender='boy',map='HALL'},specialSaveWarpFlags=1,gen3RsEndingReturn=tag}
    local before=S.encode(save);T.eq(M.apply(save,data),false,'invalid marker is not applied')
    T.eq(S.encode(save),before,'unknown marker and bits stay intact')
  end
  local old={version=version,player={map='HALL'},specialSaveWarpFlags=1}
  T.eq(M.apply(old,data),false,'unrelated old RS bit alone cannot relocate a save')
  local missing={data={maps={},constants={}},save={version=version},writeSave=function()error('must not write')end}
  T.eq(M.write(missing),false,'missing bedroom fails before IO')
end
for _,version in ipairs{'emerald','firered','leafgreen','gold','red'}do
  local save={version=version,player={map='HALL'},specialSaveWarpFlags=0x81,
    gen3RsEndingReturn={format=1,version=version,map='BOY',x=4,y=2}}
  local before=S.encode(save)
  T.eq(M.apply(save,data),false,'other edition keeps its original return flow')
  T.eq(M.write({data=data,save=save}),false,'other edition cannot enter RS save bridge')
  T.eq(S.encode(save),before,'other edition remains unchanged')
end
T.finish('RS League atomic save refusal, retry, ROM home, one-shot continue and edition isolation')
