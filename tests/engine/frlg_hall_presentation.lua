-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local H=require('src.ui.Gen3HallOfFameFRLG');local Music=require('src.core.Music')
local Credits=require('src.ui.Gen3CreditsFRLG')
local Sound=require('src.core.Sound');local playId=Sound.playId;local applause={}
Sound.playId=function(data,id)applause[#applause+1]={data=data,id=id}end
local Assets=require('src.render.Assets');local Font=require('src.render.Font')
local Sprites=require('src.pokemon.Sprites');local Save=require('src.core.SaveSerializer')
local oldVersion,play,img,path=V.get(),Music.play,Assets.image,Sprites.path
local original={};for _,key in ipairs{'draw','width','pushFace','popFace','drawBox'}do original[key]=Font[key]end
local graphics=love.graphics;love.graphics={setColor=function()end,rectangle=function()end,draw=function()end}
local drawn,played,kind={},{},nil
Font.draw=function(s)drawn[#drawn+1]=s end;Font.width=function(s)return#s*5 end
Font.pushFace=function()return true end;Font.popFace=function()end;Font.drawBox=function()end
Assets.image=function()return{getDimensions=function()return 64,64 end}end
Sprites.path=function(data,id,side,opts)kind=opts.kind;return path(data,id,side,opts)end
Music.play=function(data,song)played[#played+1]=song end
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 local mon={species='OWNED',level=42,personality=0,nickname='CUSTOM%NAME',otId=123}
 local game={data={audio={special={hallOfFame='OWNED_HALL_CUE',credits='OWNED_CREDITS_CUE'}},field={playerForms={girl={card='girl.png'}}},
  constants={},pokemon={OWNED={name='OWNED',dex=1,spriteFront='owned.png',genderRatio=254}}},
  save={version=version,player={name='LEAF',gender='girl'},party={mon},playTime={hours=123,minutes=45,seconds=6}}}
 local before=Save.encode(game.save);local h=H.new(game,{text={}},function()end)
 T.eq(kind,'hof','species sprite hook receives its documented ceremony context')
 game.input={wasPressed=function()return false end}
 h.phase='fly';h.index=#h.mons+1;h:update()
 T.eq(applause[#applause].id,98,'ceremony uses its native FR/LG applause ID')
 T.eq(applause[#applause].data,game.data,'native applause belongs to the ceremony cartridge')
 T.eq(h.phase,'welcome','applause starts on the actual welcome transition')
 h:enter();T.eq(played[#played],'OWNED_HALL_CUE','Hall uses the selected cartridge/conversion role')
 Credits.enter({game=game});T.eq(played[#played],'OWNED_CREDITS_CUE','credits use their own cartridge role')
 local spy=Music.play
 Music.play=function(data,song)if song=='OWNED_CREDITS_CUE'then error('owned source failure')end;return spy(data,song)end
 Credits.enter({game=game});T.eq(played[#played],'OWNED_HALL_CUE','raised credits errors use the correct Hall role')
 Music.play=spy
 h.phase='champion';drawn={};h:draw()
 T.check(table.concat(drawn,'|'):find('123:45',1,true)~=nil,'table clock is displayed without rewriting save')
 T.eq(Save.encode(game.save),before,'ceremony construction and draw preserve all saved fields')
 for _,clock in ipairs{123*3600+45*60+6,'445506',{hours=123,mins=45,secs=6,vblanks=30}}do
  game.save.playTime=clock;h.phase='champion';drawn={};before=Save.encode(game.save);h:draw()
  T.check(table.concat(drawn,'|'):find('123:45',1,true)~=nil,'all established play-clock forms agree')
  T.eq(Save.encode(game.save),before,'clock formatting stays read-only')
 end
 game.save.playTime=nil;game.save.playSeconds=123*3600+45*60;drawn={};h:draw()
 T.check(table.concat(drawn,'|'):find('123:45',1,true)~=nil,'legacy playSeconds fallback remains supported')
 for _,sex in ipairs{'male','female','genderless'}do
  mon.gender=sex;h.phase='hold';h.index=1;drawn={};before=Save.encode(game.save);h:draw()
  local text=table.concat(drawn,'|')
  T.check(text:find('CUSTOM%NAME',1,true)~=nil,'custom nickname is unchanged')
  T.eq(text:find('♂',1,true)~=nil,sex=='male','male glyph follows authoritative gender')
  T.eq(text:find('♀',1,true)~=nil,sex=='female','female glyph follows authoritative gender')
  T.eq(Save.encode(game.save),before,'gender formatting leaves saved identity untouched')
 end
 mon.gender=nil;drawn={};h:draw()
 T.check(table.concat(drawn,'|'):find('♀',1,true)~=nil,'native species/PID gender works without a stored string')
 game.data.audio.special.hallOfFame=nil;h:enter()
 T.eq(played[#played],'Music_HallOfFame','old-cache fallback remains delegated to Music.special')
end
Music.play,Assets.image,Sprites.path=play,img,path
Sound.playId=playId
for key,value in pairs(original)do Font[key]=value end
love.graphics=graphics;V.set(oldVersion)
T.finish('FRLG Hall cartridge music, canonical clock, native gender and sprite hook ownership')
