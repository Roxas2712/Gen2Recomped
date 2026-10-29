package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local A=require('src.import.Gen3RsHealthboxAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local writes={};local palette={}
for i=0,15 do palette[i]=i*100 end
local c={}
function c:palFrom()return palette end
function c:pal()return palette end
function c:strip(key,raw,w,h,n,pal,bpp,tile)
  if key=='blank'then T.eq(tile,43,'native blank name tile')end
  return{png=key..'.png'}
end
function c:png(name,w,h,pixels,pal)
  T.eq(w,24);T.eq(h,8);T.eq(type(pixels),'table','indexed PNG API consumes numeric pixels')
  T.eq(#pixels,w*h)
  for _,value in ipairs(pixels)do T.check(type(value)=='number'and value%1==0 and pal[value]~=nil)end
  writes[#writes+1]=name;return name
end
local rom={}
function rom:readString(off,size)
  local out={}
  for i=0,size-1 do out[i+1]=string.char(math.floor(i/32)%16*17)end
  return table.concat(out)
end
local x={version='ruby',_constants={},beginStage=function()end}
local function load(name)
  if name=='src.import.gba.rs.assets'then return{context=function()return c end,finish=function()return true end}end
  if name=='src.import.gba.rse.boot_gfx'then return{palList=function(p)
    local out={};for i=0,15 do out[i+1]=p[i]end;return out end}end
  if name=='src.import.gba.syms'then return{of=function()return{}end}end
  if name=='src.import.gba.games.rs.text_chrome'then return function()end end
  if name=='src.import.gba.games.rs.battle'then return function(v)
    v.BATTLE_UI={healthbox_elements=100,healthbox_elements_span_size=0xec0,healthbox_pal=1,healthbar_pal=33}
  end end
  error(name)
end
A.extract(x,load,rom,{})
local s=x._constants.gen3RsHealthbox
T.eq(#writes,20,'all five statuses for all four native battler slots')
T.eq(writes[1],'status_0_PSN.png','RS ailment one is poison')
T.eq(writes[2],'status_0_PAR.png','RS ailment two is paralysis')
T.check(A.valid(s,'ruby'));T.check(not A.valid(s,'sapphire'),'edition identity cannot cross caches')
local oldRead,oldExists=Fs.read,Fs.exists
Fs.read=function()return Writer.encode({gen3RsHealthbox=s})end
Fs.exists=function()return true end
T.eq(#A.missing('ruby'),0)
Fs.exists=function(p)return p~='status_3_BRN.png'end
T.eq(A.missing('ruby')[1],'status_3_BRN.png','a missing far-slot status invalidates readiness')
local word=s.palette[1];s.palette[1]='not a palette'
T.check(not A.valid(s,'ruby'));s.palette[1]=word
local row=s.status[1];s.status[1]=false;T.check(not A.valid(s,'ruby'));s.status[1]=row
Fs.read,Fs.exists=oldRead,oldExists
local Native=require('src.battle.Gen3Battle')
local px,py=Native.hudPlace({},'player',64,0)
T.eq(px,126);T.eq(py,72,'tall player sheet retains the original 64x32 OAM origin')
local ox,oy=Native.hudPlace({},'opponent',32,0)
T.eq(ox,12);T.eq(oy,14)
local coords={gen3BattlerCoords={healthbox={singlesPlayer={x=158,y=88}}}}
px,py=Native.hudPlace(coords,'player',64,80)
T.eq(px,206,'wide presentation moves only the player edge');T.eq(py,72)
-- A hidden level must erase the baked prefix as well as the dynamic digits.
local M=require('src.battle.Gen3RsHealthbox')
local Images=require('src.render.Assets');local Care=require('src.pokemon.DayCare');local Level=require('src.ui.LevelDisplay')
local Version=require('src.core.GameVersion')
local oldG,oldImage,oldGender,oldLevel,oldGet=love.graphics,Images.image,Care.gender,Level.visible,Version.get
local rectangles,letters={},{}
local scissor={4,5,400,400}
love.graphics={getScissor=function()return unpack(scissor)end,
 setScissor=function(...)scissor={...}end,setColor=function()end,
 rectangle=function(_,x0,y0,w,h)rectangles[#rectangles+1]={x0,y0,w,h}end,
 draw=function()end,newQuad=function()return{}end}
Images.image=function()return{}end;Care.gender=function()end;Level.visible=function()return false end
Version.get=function()return'ruby'end
local b={data={constants={gen3RsHealthbox=s}},isDouble=function()return false end,statusLabel=function()return'CUSTOM'end}
local mon={position=0,name='TEST',mon={species='TEST',level=39,stats={hp=114}}}
local font={measure=function(text)return #text*5 end,draw=function(text)letters[#letters+1]=text end}
T.eq(M.draw(b,mon,100,100,true,font,{hp=44}),true)
local erased=false
for _,r in ipairs(rectangles)do if r[1]==172 and r[2]==108 and r[3]==24 and r[4]==8 then erased=true end end
T.check(erased,'hidden level clears its complete native prefix-and-digits row')
for _,text in ipairs(letters)do T.check(not text:find('39',1,true),'hidden level cannot draw its digits')end
mon.shownStatus='CUSTOM'
T.eq(M.draw(b,mon,100,100,true,font,{hp=44}),false,'custom status labels retain the existing host painter')
mon.shownStatus=nil;font.draw=function()error('intentional healthbox font failure')end
T.raises(function()M.draw(b,mon,100,100,true,font,{hp=44})end,'intentional healthbox font failure')
T.eq(table.concat(scissor,','),'4,5,400,400','font errors restore the caller scissor')
local Performance=require('src.core.Performance')
local seen,trace={},{}
font.draw=function(value,x0,y0,opts)
  seen[#seen+1]=opts
  trace[#trace+1]={value,x0,y0,opts.colors.fg[1],opts.colors.shadow[2]}
end
local function draw()
  seen,trace={},{};M.draw(b,mon,100,100,true,font,{hp=44});return seen,trace
end
local on,expected=draw();local again=draw()
T.eq(on[1],again[1],'unchanged native rows reuse their read-only text options')
Performance.rsBattlePaintCache=false
local off,control=draw()
T.same(control,expected,'cache rollback preserves all glyphs, coordinates and colors')
T.neq(off[1],on[1],'rollback uses fresh native row options')
Performance.rsBattlePaintCache=true
s.palette[2]=32767
local edited,changed=draw()
T.neq(edited[1],on[1],'in-place palette edits invalidate cached options')
T.neq(changed[1][4],expected[1][4],'edited palette reaches the actual native painter')
love.graphics,Images.image,Care.gender,Level.visible,Version.get=oldG,oldImage,oldGender,oldLevel,oldGet
T.finish('RS native healthbox resources, all status variants and OAM anchors')
