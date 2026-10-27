package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local V=require('src.core.GameVersion');local P=require('src.battle.Gen3TrainerPresentation')
local B=require('src.battle.BattleState');local X=require('src.import.RomExtractorGen3')
local save={player={rival='Zoë-7'}}
local team={{species='BULBASAUR',level=5}}
for _,v in ipairs({'firered','leafgreen'})do
 V.set(v)
 for _,class in ipairs({81,89,90})do
  local raw={id='TERRY_327',index=327,class=class,name='TERRY',parties={team},aiFlags=7}
  local shown=P.view(raw,save)
  T.eq(shown.name,'Zoë-7','native '..v..' rival/champion class '..class..' uses custom saved name')
  T.eq(raw.name,'TERRY','rival view never renames shared imported definition')
  T.eq(shown.id,raw.id,'stable trainer key survives name view')
  T.eq(shown.parties,raw.parties,'native trainer party references remain authoritative')
  T.eq(shown.aiFlags,7,'AI metadata survives presentation overlay')
 end
 local raw={class=57,name='TERRY'}
 T.eq(P.view(raw,save),raw,'an ordinary trainer with placeholder-like name is not the rival')
 T.eq(P.view({class=81,name='TERRY'},{player={rival=''}}).name,'TERRY','absent custom name retains native header fallback')
 local audio={trainer='T',rival='R',gym='G',elite='E',final='F'}
 for class,want in pairs({[81]='trainer',[89]='trainer',[84]='gym',[87]='elite',[90]='final'})do
  local b=setmetatable({kind='trainer',trainer={class=class,name='Zoë-7'},data={audio={battle=audio}},game={save=save}},{__index=B})
  T.eq(b:gen3MusicKind(),want,'native class '..class..' selects correct battle role before rival-name heuristic')
  T.eq(b.isGymLeader,class==84,'only native gym leaders set the leader happiness marker')
 end
 local written={};local defs={R={class=90,name='TERRY',id='R',parties={team}},G={class=84,name='BROCK',id='G'}}
 local extractor=setmetatable({manifest={version=v,frlgItemMenu={}},_constants={},_trainers=defs,
  beginStage=function()end,need=function()return 0x1000 end,
  readString=function(_,at,size)assert(size==13);return 'CLASS_'..tostring((at-0x1000)/13)end,
  write=function(_,name,rows)written[name]=rows end,facilityTrainerRows=function()return nil end},{__index=X})
 extractor:extractTrainerClasses()
 T.eq(extractor._constants.trainerClasses[106],'CLASS_106','all 107 native class strings are imported')
 T.eq(extractor._constants.trainerClasses[107],nil,'class read stops at actual FRLG boundary')
 T.eq(defs.R.className,'CLASS_90','late rival/champion record receives its class label')
 T.eq(defs.G.className,'CLASS_84','Brock receives native LEADER class label')
 T.eq(defs.R.parties[1],team,'class enrichment does not rebuild trainer teams')
 T.eq(extractor._constants.gen3TrainerPresentation.classCount,107,'cache advertises complete native class table')
end
for _,v in ipairs({'ruby','sapphire','emerald','gold','red'})do
 V.set(v);local raw={class=81,name='MAY'}
 T.eq(P.view(raw,save),raw,'other edition retains its own trainer identity: '..v)
 T.eq(P.classCount(v),67,'other edition keeps previous extraction contract: '..v)
end
for _,v in ipairs({'ruby','sapphire'})do
 V.set(v)
 -- RS reads the original class 46 and excludes Wally by cartridge name.
 -- Class 0 is an ordinary trainer, even when a save uses the same name.
 for _,row in ipairs({{46,'MAY','rival'},{46,'BRENDAN','rival'},
                       {46,'WALLY','trainer'},{0,'MAY','trainer'}})do
  local b=setmetatable({kind='trainer',trainer={class=row[1],name=row[2]},
    data={audio={battle={trainer='T',rival='R'}}},
    game={save={player={rival='MAY'}}}},{__index=B})
  T.eq(b:gen3MusicKind(),row[3],'native RS rival class and Wally exception: '..v..' '..row[2]..' '..row[1])
 end
end
V.set('emerald')
local b=setmetatable({kind='trainer',trainer={class=0,name='MAY'},data={audio={battle={trainer='T',rival='R'}}},game={save={player={rival='MAY'}}}},{__index=B})
T.eq(b:gen3MusicKind(),'rival','Emerald retains its own rival-name fallback')
T.finish('FRLG rival identity, 107 native classes and battle roles')
