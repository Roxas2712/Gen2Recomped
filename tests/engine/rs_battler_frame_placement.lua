-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.battle.Gen3RsBattlerPlacement')
local W=require('src.import.LuaWriter')
local img={getWidth=function()return 64 end,getHeight=function()return 64 end}
local rows={singles={{x=72,y=80},{x=176,y=40}},doubles={{x=32,y=80},{x=200,y=40},{x=90,y=88},{x=152,y=32}}}
local defs={SCEPTILE={frontPicCoords={yOffset=0},backPicCoords={yOffset=1}},
 WINGULL={frontPicCoords={yOffset=24},backPicCoords={yOffset=14}},
 LUNATONE={frontPicCoords={yOffset=9},backPicCoords={yOffset=5}},
 SOLROCK={frontPicCoords={yOffset=1},backPicCoords={yOffset=5}}}
local b={data={constants={gen3BattlerCoords=rows,gen3RsHealthbox={version='ruby'},gen3Elevation={LUNATONE=13,SOLROCK=4}},pokemon=defs},isDouble=function()return true end}
local actors={ {position=0,isPlayer=true,mon={species='SCEPTILE'}},
 {position=1,isPlayer=false,mon={species='LUNATONE'}},
 {position=2,isPlayer=true,mon={species='WINGULL'}},
 {position=3,isPlayer=false,mon={species='SOLROCK'}} }
local expected={{0,49},{168,4},{58,70},{120,-3}}
local before=W.encode(b.data)
for _,edition in ipairs{'ruby','sapphire'}do
 b.data.constants.gen3RsHealthbox.version=edition
 for i,a in ipairs(actors)do
  local x,y=P.place(b,a,img,1,0);T.eq(x,expected[i][1]);T.eq(y,expected[i][2])
  x,y=P.place(b,a,img,0.5,40);T.eq(x,expected[i][1]+56);T.eq(y,expected[i][2]+16,'scale keeps native frame centre')
 end
end
b.data.constants.gen3RsHealthbox.version='ruby';T.eq(W.encode(b.data),before,'placement never edits imported records')
b.isDouble=function()return false end
local x,y=P.place(b,actors[1],img,1,0);T.eq(x,40);T.eq(y,49)
x,y=P.place(b,actors[2],img,1,0);T.eq(x,144);T.eq(y,4,'single also uses original lift and front offset')
for _,edition in ipairs{'emerald','firered','leafgreen','gold'}do
 b.data.constants.gen3RsHealthbox.version=edition;T.eq(P.place(b,actors[1],img,1,0),nil,'other edition forwards')
end
b.data.constants.gen3RsHealthbox.version='ruby'
T.eq(P.place(b,{isPlayer=false},img,1,0),nil,'trainer retains its existing placement')
T.eq(P.place(b,actors[1],{getWidth=function()return 128 end,getHeight=function()return 64 end},1,0),nil,'custom image size forwards')
defs.SCEPTILE.backPicCoords=nil
T.eq(P.place(b,actors[1],img,1,0),nil,'missing native metadata is never guessed')
T.finish('RS native sprite frames, original front/back offsets, scaling and edition isolation')
